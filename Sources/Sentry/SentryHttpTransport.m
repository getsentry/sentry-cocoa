#import "SentryHttpTransport.h"
#import "SentryDsn.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryFileContents.h"
#import "SentryFileManager.h"
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

        [self sendAllCachedEnvelopes];
    }
    return self;
}

- (void)sendEvent:(SentryEvent *)event
{
    SentryEnvelope *eventEnvelope = [[SentryEnvelope alloc] initWithEvent:event];
    [self sendEnvelope:eventEnvelope];
}

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

    [self.fileManager storeEnvelope:envelope];
    [self sendAllCachedEnvelopes];
}

#pragma mark private methods

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
        NSURLRequest *request = [self createEnvelopeRequest:fileContents.contents
                                           didFailWithError:requestError];

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

- (NSURLRequest *)createEnvelopeRequest:(NSData *)envelopeData
                       didFailWithError:(NSError *_Nullable)error
{
    return [[SentryNSURLRequest alloc] initEnvelopeRequestWithDsn:self.options.parsedDsn
                                                          andData:envelopeData
                                                 didFailWithError:&error];
}

- (void)sendCached:(NSURLRequest *)request withFilePath:(NSString *)filePath
{
    __block SentryHttpTransport *_self = self;
    [self.requestManager
               addRequest:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            // TODO: How does beforeSend work here

            // If the response is not nil we had an internet connection.
            // We don't worry about errors here.
            if (nil != response) {
                [_self.fileManager removeFileAtPath:filePath];
                [_self.rateLimits update:response];
            }
        }];
}

@end
