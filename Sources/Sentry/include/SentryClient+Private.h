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

- (SentryId *)captureErrorIncrementingSessionErrorCount:(NSError *)error
                                              withScope:(SentryScope *)scope;

- (SentryId *)captureExceptionIncrementingSessionErrorCount:(NSException *)exception
                                                  withScope:(SentryScope *)scope;

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

- (SentryId *)captureErrorEventIncrementingSessionErrorCount:(SentryEvent *)event
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

@end

NS_ASSUME_NONNULL_END
