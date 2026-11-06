#import "SentryDefines.h"
#import "SentryHub+SwiftPrivate.h"
#import "SentryHub.h"

@class SentryClientInternal;
@class SentryEnvelopeItem;
@class SentryId;
@class SentryTransaction;
@class SentryDispatchQueueWrapper;
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

- (void)addInstalledIntegration:(SENTRY_SWIFT_MIGRATION_ID(
                                    id<SentryIntegrationProtocol>))integration
                           name:(NSString *)name;
- (void)removeAllIntegrations;

- (SentryClientInternal *_Nullable)client;

- (void)captureFatalEvent:(SentryEvent *)event;

- (void)captureFatalEvent:(SentryEvent *)event
                withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(captureFatalEvent(_:with:));

/**
 * Captures a fatal event and returns its ID, or @c SentryId.empty when no event was accepted.
 */
- (SentryId *)captureFatalEventWithResult:(SentryEvent *)event
                                withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
          preserveCrashedSessionOnFailure:(BOOL)preserveCrashedSessionOnFailure
    NS_SWIFT_NAME(captureFatalEvent(_:scope:preserveCrashedSessionOnFailure:));

/**
 * Returns YES when a fatal-event capture was accepted or intentionally discarded. Returns NO when
 * the snapshotted client became unavailable, making the capture retryable.
 */
- (BOOL)isFatalEventCaptureResultTerminal:(SentryId *)eventId client:(SentryClientInternal *)client;

#if SENTRY_HAS_UIKIT && !SDK_V10
- (void)captureFatalAppHangEvent:(SentryEvent *)event;
#endif // SENTRY_HAS_UIKIT && !SDK_V10

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

- (SentryTracer *)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
                                configuration:(SENTRY_SWIFT_MIGRATION_ID(
                                                  SentryTracerConfiguration))configuration;

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureErrorEvent:(SentryEvent *)event NS_SWIFT_NAME(captureErrorEvent(event:));

- (SentryId *)captureErrorEvent:(SentryEvent *)event
                       withHint:(SENTRY_SWIFT_MIGRATION_ID(SentryHint)_Nullable)hint;

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
             withHint:(SENTRY_SWIFT_MIGRATION_ID(SentryHint)_Nullable)hint;

- (SentryId *)captureError:(NSError *)error
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
          attachAllThreads:(nullable NSNumber *)attachAllThreads
    NS_SWIFT_NAME(captureError(_:with:attachAllThreads:));

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
              attachAllThreads:(nullable NSNumber *)attachAllThreads
    NS_SWIFT_NAME(capture(_:with:attachAllThreads:));

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
            attachAllThreads:(nullable NSNumber *)attachAllThreads
    NS_SWIFT_NAME(captureMessage(_:with:attachAllThreads:));

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments;

- (void)captureTransaction:(SENTRY_SWIFT_MIGRATION_ID(SentryTransaction))transaction
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(capture(_:with:));

- (void)captureTransaction:(SentryTransaction *)transaction
                  withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;
- (void)saveCrashTransaction:(SENTRY_SWIFT_MIGRATION_ID(SentryTransaction))transaction
    NS_SWIFT_NAME(saveCrash(_:));

- (nullable SENTRY_SWIFT_MIGRATION_ID(
    id<SentryIntegrationProtocol>))getInstalledIntegration:(Class)integrationClass;
- (NSSet<NSString *> *)installedIntegrationNames;

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (NSString *__nullable)getSessionReplayId;
#endif

@end

NS_ASSUME_NONNULL_END
