#import "SentryClient.h"

// These are forward declarations, the actual enums are implemented in Swift.
typedef NS_ENUM(NSUInteger, SentryDataCategory);
typedef NS_ENUM(NSUInteger, SentryDiscardReason);

@class SentryAttachment;
@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryHint;
@class SentryId;
@class SentryReplayEvent;
@class SentryFileManager;
@class SentryReplayRecording;
@class SentrySession;
@class SentryDefaultThreadInspector;

@protocol SentrySessionDelegate <NSObject>

- (nullable SentrySession *)incrementSessionErrors;

@end

NS_ASSUME_NONNULL_BEGIN

@protocol SentryClientAttachmentProcessor <NSObject>

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(SentryEvent *)event;

@end

@interface SentryClientInternal (Attachments)

- (void)populateHintAttachments:(SentryHint *)hint
                          scope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
          isFromPreviousProcess:(BOOL)isFromPreviousProcess;

- (NSArray<SentryAttachment *> *)processAttachmentsForEvent:(SentryEvent *)event
                                                attachments:
                                                    (NSArray<SentryAttachment *> *)attachments;

- (void)addAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor;
- (void)removeAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor;

@end

@interface SentryClientInternal ()

@property (nonatomic, strong)
    NSMutableArray<id<SentryClientAttachmentProcessor>> *attachmentProcessors;
@property (nonatomic, strong) SentryDefaultThreadInspector *threadInspector;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, weak, nullable) id<SentrySessionDelegate> sessionDelegate;

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
- (void)storeEnvelope:(SentryEnvelope *)envelope;

- (void)captureEnvelope:(SentryEnvelope *)envelope;

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;
- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity;

/// Exposed so Swift (e.g. metrics) can reuse it to drop data when the client is disabled.
/// Broader than `isEnabled` in `SentryClient.h`: `isEnabled` only reflects `close`,
/// while `isDisabled` also returns YES for `options.enabled == false` or no DSN.
@property (nonatomic, assign, readonly) BOOL isDisabled;

/// Logs a debug message that data is dropped because the client is disabled. Exposed so Swift
/// (e.g. metrics) logs the same message as event/envelope capture when dropping data.
- (void)logDisabledMessage;

@end

@interface SentryClientInternal (Telemetry)

- (void)_swiftCaptureLog:(NSObject *)log
               withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(_swiftCaptureLog(_:with:));

/// Exposes the Telemetry Processor so Swift code can forward metrics directly without crossing the
/// ObjC boundary. SentryMetric is a Swift struct and cannot be passed through ObjC methods, so
/// we use a Swift extension on SentryClientInternal.
/// The return type is `id` (not `id<SentryObjCTelemetryProcessor>`) to avoid a
/// circular dependency: the protocol is defined in Swift and cannot be referenced in ObjC headers
/// that Swift imports.
- (SENTRY_SWIFT_MIGRATION_ID(id<SentryObjCTelemetryProcessor>))getTelemetryProcessor;

/// Records a dropped trace metric. Boxed in `SentryMetricObjC` (typed `id`, same header/Swift
/// constraint as `getTelemetryProcessor` above) because `SentryMetric` is a Swift struct.
- (void)recordDroppedTraceMetricInClientReport:(SENTRY_SWIFT_MIGRATION_ID(SentryMetricObjC))metric;

@end

@interface SentryClientInternal (EventCapturePrivate)

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureError:(NSError *)error
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
          attachAllThreads:(nullable NSNumber *)attachAllThreads
    NS_SWIFT_NAME(capture(error:scope:attachAllThreads:));

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
              attachAllThreads:(nullable NSNumber *)attachAllThreads
    NS_SWIFT_NAME(capture(exception:scope:attachAllThreads:));

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
            attachAllThreads:(nullable NSNumber *)attachAllThreads
    NS_SWIFT_NAME(capture(message:scope:attachAllThreads:));

- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                      hint:(nullable SentryHint *)hint NS_SWIFT_NAME(capture(event:scope:hint:));

- (SentryId *)captureError:(NSError *)error
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                      hint:(nullable SentryHint *)hint NS_SWIFT_NAME(capture(error:scope:hint:));

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                          hint:(nullable SentryHint *)hint
    NS_SWIFT_NAME(capture(exception:scope:hint:));

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                        hint:(nullable SentryHint *)hint
    NS_SWIFT_NAME(capture(message:scope:hint:));

@end

@interface SentryClientInternal (EventPreparation)

- (nullable SentryEvent *)prepareEvent:(SentryEvent *)event
                             withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                                  hint:(SentryHint *)hint;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                          currentScope:
                              (nullable SENTRY_SWIFT_MIGRATION_ID(SentryScope))currentScope;

- (void)recordPartiallyDroppedSpans:(SentryTransaction *)transaction
                         withReason:(SentryDiscardReason)reason
               withCurrentSpanCount:(NSUInteger *)currentSpanCount;

- (BOOL)isSampled:(nullable NSNumber *)sampleRate;

- (nullable SentryEvent *)callEventProcessors:(SentryEvent *)event;

- (void)recordLost:(BOOL)eventIsNotATransaction reason:(SentryDiscardReason)reason;

- (void)recordLostSpanWithReason:(SentryDiscardReason)reason quantity:(NSUInteger)quantity;

@end

@interface SentryClientInternal (EventSending)

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace;

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                      hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent;

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent
                      hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
                       hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(nullable SentrySession *)session
              withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope;

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(nullable SentrySession *)session
              withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                   hint:(SentryHint *)hint;

@end

@interface SentryClientInternal (SessionsAndCrashes)

- (SentryId *)captureFatalEvent:(SentryEvent *)event
                      withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(captureFatalEvent(_:with:));

- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(captureFatalEvent(_:with:with:));

- (void)saveCrashTransaction:(SENTRY_SWIFT_MIGRATION_ID(SentryTransaction))transaction
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(saveCrashTransaction(transaction:scope:));

- (SentryId *)captureEventIncrementingSessionErrorCount:(SentryEvent *)event
                                              withScope:
                                                  (SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(captureEventIncrementingSessionErrorCount(_:with:));

- (SentryId *)captureEventIncrementingSessionErrorCount:(SentryEvent *)event
                                              withScope:(SENTRY_SWIFT_MIGRATION_ID(
                                                            SentryScope))scope
                                                   hint:(SentryHint *)hint;

- (void)captureSession:(SentrySession *)session NS_SWIFT_NAME(capture(session:));

@end

@interface SentryClientInternal (ReplayAndFeedback)

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(capture(_:replayRecording:video:with:));

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments
                            scope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                     currentScope:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryScope))currentScope;

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments
                            scope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope;

@end

NS_ASSUME_NONNULL_END
