#import "SentryHttpTransport.h"
#import "SentryDsn.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryFileContents.h"
#import "SentryLog.h"
#import "SentryNSURLRequest.h"
#import "SentryOptions.h"
#import "SentryRateLimitCategoryMapper.h"
#import "SentrySerialization.h"

@interface
SentryHttpTransport ()

@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) id<SentryRequestManager> requestManager;
@property (nonatomic, weak) SentryOptions *options;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, strong) SentryEnvelopeRateLimit *envelopeRateLimit;

@end

@implementation SentryHttpTransport

- (id)initWithOptions:(SentryOptions *)options
          sentryFileManager:(SentryFileManager *)sentryFileManager
       sentryRequestManager:(id<SentryRequestManager>)sentryRequestManager
           sentryRateLimits:(id<SentryRateLimits>)sentryRateLimits
    sentryEnvelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
{
    if (self = [super init]) {
        self.options = options;
        self.requestManager = sentryRequestManager;
        self.fileManager = sentryFileManager;
        self.rateLimits = sentryRateLimits;
        self.envelopeRateLimit = envelopeRateLimit;

        [self setupQueueing];
        [self sendAllCachedEnvelopes];
    }
    return self;
}

- (void)sendEvent:(SentryEvent *)event
{
    SentryEnvelope *eventEnvelope = [[SentryEnvelope alloc] initWithEvent:event];
    [self sendEnvelope:eventEnvelope];
}

// TODO: needs refactoring
- (void)sendEnvelope:(SentryEnvelope *)envelope
{
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled. (options.enabled = false)"
                         andLevel:kSentryLogLevelDebug];
        return;
    }

    envelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];

    if (envelope.items.count == 0) {
        [SentryLog logWithMessage:@"RateLimit is active for all envelope items."
                         andLevel:kSentryLogLevelDebug];
        return;
    }

    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
    NSURLRequest *request = [self createEnvelopeRequest:envelope didFailWithError:requestError];

    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        return;
    }

    // TODO: We do multiple serializations here, we can improve this
    NSString *storedEnvelopePath = [self.fileManager storeEnvelope:envelope];

    [self sendRequest:request storedPath:storedEnvelopePath];
}

#pragma mark private methods

- (void)setupQueueing
{
    self.shouldQueueEvent = ^BOOL(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // Taken from Apple Docs:
        // If a response from the server is received, regardless of whether the
        // request completes successfully or fails, the response parameter
        // contains that information.
        // In case response is nil, we want to queue the event locally since
        // this indicates no internet connection.
        // In all other cases we don't want to retry sending it and just discard
        // the event.
        return response == nil;
    };
}

- (NSURLRequest *)createEnvelopeRequest:(SentryEnvelope *)envelope
                       didFailWithError:(NSError *_Nullable)error
{
    return [[SentryNSURLRequest alloc]
        initEnvelopeRequestWithDsn:self.options.parsedDsn
                           andData:[SentrySerialization dataWithEnvelope:envelope error:&error]
                  didFailWithError:&error];
}

- (void)sendRequest:(NSURLRequest *)request storedPath:(NSString *)storedPath
{
    __block SentryHttpTransport *_self = self;
    [self sendRequest:request
        withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            if (self.shouldQueueEvent == nil || !self.shouldQueueEvent(response, error)) {
                // don't need to queue this -> it most likely got sent
                // thus we can remove the event from disk
                [_self.fileManager removeFileAtPath:storedPath];
                if (nil == error) {
                    [_self sendAllCachedEnvelopes];
                }
            }
        }];
}

- (void)sendRequest:(NSURLRequest *)request
    withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler
{
    __block SentryHttpTransport *_self = self;
    [self.requestManager
               addRequest:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            [_self.rateLimits update:response];
            if (completionHandler) {
                completionHandler(response, error);
            }
        }];
}

/**
 * validation for `sendEvent:...`
 *
 * @return BOOL NO if options.enabled = false or rate limit exceeded
 */
- (BOOL)isReadyToSend:(SentryRateLimitCategory)category
{
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled. (options.enabled = false)"
                         andLevel:kSentryLogLevelDebug];
        return NO;
    }

    return ![self.rateLimits isRateLimitActive:category];
}

// TODO: This has to move somewhere else, we are missing the whole beforeSend
// flow
- (void)sendAllCachedEnvelopes
{
    if (![self.requestManager isReady]) {
        return;
    }

    for (SentryFileContents *fileContents in [self.fileManager getAllEnvelopes]) {
        SentryEnvelope *envelope = [SentrySerialization envelopeWithData:fileContents.contents];
        if (nil == envelope) {
            [self.fileManager removeFileAtPath:fileContents.path];
            continue;
        }

        SentryEnvelope *rateLimitedEnvelope =
            [self.envelopeRateLimit removeRateLimitedItems:envelope];
        if (rateLimitedEnvelope.items.count == 0) {
            [self.fileManager removeFileAtPath:fileContents.path];
            continue;
        }

        NSError *requestError = nil;
        NSURLRequest *request = [self createEnvelopeRequest:envelope didFailWithError:requestError];

        if (nil != requestError) {
            [SentryLog logWithMessage:requestError.localizedDescription
                             andLevel:kSentryLogLevelError];
            [self.fileManager removeFileAtPath:fileContents.path];
            continue;
        } else {
            [self sendCached:request withFilePath:fileContents.path];
        }
    }
}

- (void)sendCached:(NSURLRequest *)request withFilePath:(NSString *)filePath
{
    [self sendRequest:request
        withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            // TODO: How does beforeSend work here

            // If the response is not nil we had an internet connection.
            // We don't worry about errors here.
            if (nil != response) {
                [self.fileManager removeFileAtPath:filePath];
            }
        }];
}

@end
