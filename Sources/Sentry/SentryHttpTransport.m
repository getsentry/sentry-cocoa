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
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, strong) SentryEnvelopeRateLimit *envelopeRateLimit;

/**
 * Synching with a dispatch queue to have concurrent reads and writes as barrier blocks is roughly
 * 30% slower than using atomic here.
 */
@property (atomic) BOOL isSending;

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
        _isSending = NO;

        [self sendAllCachedEnvelopes];
    }
    return self;
}

- (void)sendEvent:(SentryEvent *)event
{
    SentryEnvelope *eventEnvelope = [[SentryEnvelope alloc] initWithEvent:event];
    [self sendEnvelope:eventEnvelope];
}

- (void)sendEvent:(SentryEvent *)event withSession:(SentrySession *)session
{
    NSMutableArray<SentryEnvelopeItem *> *items = [NSMutableArray new];
    [items addObject:[[SentryEnvelopeItem alloc] initWithSession:session]];
    [items addObject:[[SentryEnvelopeItem alloc] initWithEvent:event]];

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:event.eventId items:items];

    [self sendEnvelope:envelope];
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

// TODO: This has to move somewhere else, we are missing the whole beforeSend flow
- (void)sendAllCachedEnvelopes
{
    @synchronized(self) {
        if (self.isSending || ![self.requestManager isReady]) {
            return;
        }
        self.isSending = YES;
    }

    SentryFileContents *envelopeFileContents = [self.fileManager getOldestEnvelope];
    if (nil == envelopeFileContents) {
        self.isSending = NO;
        return;
    }

    SentryEnvelope *envelope = [SentrySerialization envelopeWithData:envelopeFileContents.contents];
    if (nil == envelope) {
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    }

    SentryEnvelope *rateLimitedEnvelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];
    if (rateLimitedEnvelope.items.count == 0) {
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    }

    NSError *requestError = nil;
    NSURLRequest *request = [self createEnvelopeRequest:rateLimitedEnvelope
                                       didFailWithError:requestError];

    if (nil != requestError) {
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    } else {
        [self sendEnvelope:envelopeFileContents.path request:request];
    }
}

- (void)deleteEnvelopeAndSendNext:(NSString *)envelopePath
{
    [self.fileManager removeFileAtPath:envelopePath];
    self.isSending = NO;
    [self sendAllCachedEnvelopes];
    return;
}

- (NSURLRequest *)createEnvelopeRequest:(SentryEnvelope *)envelope
                       didFailWithError:(NSError *_Nullable)error
{
    return [[SentryNSURLRequest alloc]
        initEnvelopeRequestWithDsn:self.options.parsedDsn
                           andData:[SentrySerialization dataWithEnvelope:envelope error:&error]
                  didFailWithError:&error];
}

- (void)sendEnvelope:(NSString *)envelopePath request:(NSURLRequest *)request
{
    __block SentryHttpTransport *_self = self;
    [self.requestManager
               addRequest:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            // TODO: How does beforeSend work here

            // If the response is not nil we had an internet connection.
            // We don't worry about errors here.
            if (nil != response) {
                [_self.rateLimits update:response];
                [_self deleteEnvelopeAndSendNext:envelopePath];
            } else {
                _self.isSending = NO;
            }
        }];
}

@end
