#import "SentryHub+SwiftPrivate.h"
#import "SentryHub.h"

@class SentryEnvelopeItem;
@class SentryId;
@class SentryScope;
@class SentryTransaction;
@class SentryDispatchQueueWrapper;
@class SentryEnvelope;
@class SentrySession;
@class SentryTracer;
@class SentryTracerConfiguration;
@class SentryReplayEvent;
@class SentryAttachment;
@class SentryReplayRecording;
@protocol SentryIntegrationProtocol;
@protocol SentrySessionListener;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHubInternal ()

@property (nullable, nonatomic, strong) SentrySession *session;

@property (nonatomic, strong) NSMutableArray<id<SentryIntegrationProtocol>> *installedIntegrations;

@property (nonatomic, readonly, strong) NSObject *_swiftLogger;

/**
 * Every integration starts with "Sentry" and ends with "Integration". To keep the payload of the
 * event small we remove both.
 */
- (NSArray<NSString *> *)trimmedInstalledIntegrationNames;

- (void)addInstalledIntegration:(id<SentryIntegrationProtocol>)integration name:(NSString *)name;
- (void)removeAllIntegrations;

- (SentryClientInternal *_Nullable)client;

- (void)captureFatalEvent:(SentryEvent *)event;

- (void)captureFatalEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

#if SENTRY_HAS_UIKIT
- (void)captureFatalAppHangEvent:(SentryEvent *)event;
#endif // SENTRY_HAS_UIKIT

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

- (SentryTracer *)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
                                configuration:(SentryTracerConfiguration *)configuration;

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureErrorEvent:(SentryEvent *)event NS_SWIFT_NAME(captureErrorEvent(event:));

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments;

- (void)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope;

- (void)captureTransaction:(SentryTransaction *)transaction
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;
- (void)saveCrashTransaction:(SentryTransaction *)transaction;

- (void)storeEnvelope:(SentryEnvelope *)envelope;
- (void)captureEnvelope:(SentryEnvelope *)envelope;

- (nullable id<SentryIntegrationProtocol>)getInstalledIntegration:(Class)integrationClass;
- (NSSet<NSString *> *)installedIntegrationNames;

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (NSString *__nullable)getSessionReplayId;
#endif

@end

NS_ASSUME_NONNULL_END
