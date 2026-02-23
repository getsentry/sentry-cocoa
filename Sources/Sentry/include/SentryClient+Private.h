#import "SentryClient.h"
#import "SentryDataCategory.h"
#import "SentryDiscardReason.h"

@class SentryAttachment;
@class SentryEnvelope;
@class SentryEnvelopeItem;
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

@interface SentryClientInternal ()

@property (nonatomic, strong)
    NSMutableArray<id<SentryClientAttachmentProcessor>> *attachmentProcessors;
@property (nonatomic, strong) SentryDefaultThreadInspector *threadInspector;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, weak, nullable) id<SentrySessionDelegate> sessionDelegate;

- (SentryId *)captureFatalEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope;

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments
                            scope:(SentryScope *)scope;

- (void)saveCrashTransaction:(SentryTransaction *)transaction
                   withScope:(SentryScope *)scope
    NS_SWIFT_NAME(saveCrashTransaction(transaction:scope:));

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureEventIncrementingSessionErrorCount:(SentryEvent *)event
                                              withScope:(SentryScope *)scope;

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL
                 withScope:(SentryScope *)scope;

- (void)captureSession:(SentrySession *)session NS_SWIFT_NAME(capture(session:));

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
- (void)storeEnvelope:(SentryEnvelope *)envelope;

- (void)captureEnvelope:(SentryEnvelope *)envelope;

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;
- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity;

- (void)addAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor;
- (void)removeAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor;

- (void)_swiftCaptureLog:(NSObject *)log withScope:(SentryScope *)scope;

/// Exposes the Telemetry Processor so Swift code can forward metrics directly without crossing the
/// ObjC boundary. SentryMetric is a Swift struct and cannot be passed through ObjC methods, so
/// we use a Swift extension on SentryClientInternal.
/// The return type is `id` (not `id<SentryObjCTelemetryProcessor>`) to avoid a
/// circular dependency: the protocol is defined in Swift and cannot be referenced in ObjC headers
/// that Swift imports.
- (id)getTelemetryProcessor; 

@end

NS_ASSUME_NONNULL_END
