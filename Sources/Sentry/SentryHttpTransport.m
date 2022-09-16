#import "SentryHttpTransport.h"
#import "SentryClientReport.h"
#import "SentryCurrentDate.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDiscardReasonMapper.h"
#import "SentryDiscardedEvent.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDsn.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryEvent.h"
#import "SentryFileContents.h"
#import "SentryFileManager.h"
#import "SentryLog.h"
#import "SentryNSURLRequest.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"

@interface
SentryHttpTransport ()

@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) id<SentryRequestManager> requestManager;
@property (nonatomic, strong) SentryNSURLRequestBuilder *requestBuilder;
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, strong) SentryEnvelopeRateLimit *envelopeRateLimit;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) dispatch_group_t dispatchGroup;

/**
 * Relay expects the discarded events split by data category and reason; see
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 * We could use nested dictionaries, but instead, we use a dictionary with key
 * `data-category:reason` and value `SentryDiscardedEvent` because it's easier to read and type.
 */
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, SentryDiscardedEvent *> *discardedEvents;

/**
 * Synching with a dispatch queue to have concurrent reads and writes as barrier blocks is roughly
 * 30% slower than using atomic here.
 */
@property (atomic) BOOL isSending;

@property (atomic) BOOL isFlushing;

@end

@implementation SentryHttpTransport

- (id)initWithOptions:(SentryOptions *)options
             fileManager:(SentryFileManager *)fileManager
          requestManager:(id<SentryRequestManager>)requestManager
          requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
              rateLimits:(id<SentryRateLimits>)rateLimits
       envelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.options = options;
        self.requestManager = requestManager;
        self.requestBuilder = requestBuilder;
        self.fileManager = fileManager;
        self.rateLimits = rateLimits;
        self.envelopeRateLimit = envelopeRateLimit;
        self.dispatchQueue = dispatchQueueWrapper;
        self.dispatchGroup = dispatch_group_create();
        _isSending = NO;
        _isFlushing = NO;
        self.discardedEvents = [NSMutableDictionary new];
        [self.envelopeRateLimit setDelegate:self];
        [self.fileManager setDelegate:self];

        [self sendAllCachedEnvelopes];
    }
    return self;
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
{
    envelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];

    if (envelope.items.count == 0) {
        SENTRY_LOG_DEBUG(@"RateLimit is active for all envelope items.");
        return;
    }

    SentryEnvelope *envelopeToStore = [self addClientReportTo:envelope];

    // With this we accept the a tradeoff. We might loose some envelopes when a hard crash happens,
    // because this being done on a background thread, but instead we don't block the calling
    // thread, which could be the main thread.
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        [self.fileManager storeEnvelope:envelopeToStore];
        [self sendAllCachedEnvelopes];
    }];
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    if (!self.options.sendClientReports) {
        return;
    }

    NSString *key = [NSString stringWithFormat:@"%@:%@", nameForSentryDataCategory(category),
                              nameForSentryDiscardReason(reason)];

    @synchronized(self.discardedEvents) {
        SentryDiscardedEvent *event = self.discardedEvents[key];
        NSUInteger quantity = 1;
        if (event != nil) {
            quantity = event.quantity + 1;
        }

        event = [[SentryDiscardedEvent alloc] initWithReason:reason
                                                    category:category
                                                    quantity:quantity];

        self.discardedEvents[key] = event;
    }
}

- (BOOL)flush:(NSTimeInterval)timeout
{
    @synchronized(self) {
        if (_isFlushing) {
            SENTRY_LOG_DEBUG(@"SentryHttpTransport: Already flushing.");
            return NO;
        }

        SENTRY_LOG_DEBUG(@"SentryHttpTransport: Start flushing.");

        _isFlushing = YES;
        dispatch_group_enter(self.dispatchGroup);
    }

    [self sendAllCachedEnvelopes];

    dispatch_time_t delta = (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC);
    dispatch_time_t dispatchTimeout = dispatch_time(DISPATCH_TIME_NOW, delta);

    intptr_t result = dispatch_group_wait(self.dispatchGroup, dispatchTimeout);

    @synchronized(self) {
        self.isFlushing = NO;
    }

    if (result == 0) {
        SENTRY_LOG_DEBUG(@"SentryHttpTransport: Finished flushing.");
        return YES;
    } else {
        SENTRY_LOG_DEBUG(@"SentryHttpTransport: Flushing timed out.");
        return NO;
    }
}

/**
 * SentryEnvelopeRateLimitDelegate.
 */
- (void)envelopeItemDropped:(SentryDataCategory)dataCategory
{
    [self recordLostEvent:dataCategory reason:kSentryDiscardReasonRateLimitBackoff];
}

/**
 * SentryFileManagerDelegate.
 */
- (void)envelopeItemDeleted:(SentryDataCategory)dataCategory
{
    [self recordLostEvent:dataCategory reason:kSentryDiscardReasonCacheOverflow];
}

#pragma mark private methods

- (SentryEnvelope *)addClientReportTo:(SentryEnvelope *)envelope
{
    if (!self.options.sendClientReports) {
        return envelope;
    }

    NSArray<SentryDiscardedEvent *> *events;

    @synchronized(self.discardedEvents) {
        if (self.discardedEvents.count == 0) {
            return envelope;
        }

        events = [self.discardedEvents allValues];
        [self.discardedEvents removeAllObjects];
    }

    SentryClientReport *clientReport = [[SentryClientReport alloc] initWithDiscardedEvents:events];

    SentryEnvelopeItem *clientReportEnvelopeItem =
        [[SentryEnvelopeItem alloc] initWithClientReport:clientReport];

    NSMutableArray<SentryEnvelopeItem *> *currentItems =
        [[NSMutableArray alloc] initWithArray:envelope.items];
    [currentItems addObject:clientReportEnvelopeItem];

    return [[SentryEnvelope alloc] initWithHeader:envelope.header items:currentItems];
}

- (void)sendAllCachedEnvelopes
{
    @synchronized(self) {
        if (self.isSending || ![self.requestManager isReady]) {
            [SentryLog logWithMessage:@"SentryHttpTransport: Already sending."
                             andLevel:kSentryLevelDebug];
            return;
        }
        self.isSending = YES;
    }

    SentryFileContents *envelopeFileContents = [self.fileManager getOldestEnvelope];
    if (nil == envelopeFileContents) {
        [SentryLog logWithMessage:@"SentryHttpTransport: No envelopes left to send."
                         andLevel:kSentryLevelDebug];
        [self finishedSending];
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
    NSURLRequest *request = [self.requestBuilder createEnvelopeRequest:rateLimitedEnvelope
                                                                   dsn:self.options.parsedDsn
                                                      didFailWithError:&requestError];

    if (nil != requestError) {
        [self recordLostEventFor:rateLimitedEnvelope.items];
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    } else {
        [self sendEnvelope:rateLimitedEnvelope
              envelopePath:envelopeFileContents.path
                   request:request];
    }
}

- (void)deleteEnvelopeAndSendNext:(NSString *)envelopePath
{
    [SentryLog logWithMessage:@"SentryHttpTransport: Deleting envelope and sending next."
                     andLevel:kSentryLevelDebug];
    [self.fileManager removeFileAtPath:envelopePath];
    self.isSending = NO;
    [self sendAllCachedEnvelopes];
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
        envelopePath:(NSString *)envelopePath
             request:(NSURLRequest *)request
{
    __block SentryHttpTransport *_self = self;
    [self.requestManager
               addRequest:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            // If the response is not nil we had an internet connection.
            if (error && response.statusCode != 429) {
                [_self recordLostEventFor:envelope.items];
            }

            if (nil != response) {
                [_self.rateLimits update:response];
                [_self deleteEnvelopeAndSendNext:envelopePath];
            } else {
                [SentryLog logWithMessage:@"SentryHttpTransport: No internet connection."
                                 andLevel:kSentryLevelDebug];
                [_self finishedSending];
            }
        }];
}

- (void)finishedSending
{
    SENTRY_LOG_DEBUG(@"SentryHttpTransport: Finished sending.");
    @synchronized(self) {
        self.isSending = NO;
        if (self.isFlushing) {
            SENTRY_LOG_DEBUG(@"SentryHttpTransport: Stop flushing.");
            self.isFlushing = NO;
            dispatch_group_leave(self.dispatchGroup);
        }
    }
}

- (void)recordLostEventFor:(NSArray<SentryEnvelopeItem *> *)items
{
    for (SentryEnvelopeItem *item in items) {
        NSString *itemType = item.header.type;
        // We don't want to record a lost event when it's a client report.
        // It's fine to drop it silently.
        if ([itemType isEqualToString:SentryEnvelopeItemTypeClientReport]) {
            continue;
        }
        SentryDataCategory category = sentryDataCategoryForEnvelopItemType(itemType);
        [self recordLostEvent:category reason:kSentryDiscardReasonNetworkError];
    }
}

@end
