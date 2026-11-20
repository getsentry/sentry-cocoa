#import "SentryClient.h"

@class SentryHint;
@class SentryReplayEvent;
@class SentryReplayRecording;

NS_ASSUME_NONNULL_BEGIN

// Arguments that use Swift attachment types are declared as id so Swift can import this header.
// Objective-C call sites cast back to SentryAttachment.

@interface SentryClientInternal (Attachments)

- (void)populateHintAttachments:(SentryHint *)hint
                          scope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
          isFromPreviousProcess:(BOOL)isFromPreviousProcess;

- (NSArray<SENTRY_SWIFT_MIGRATION_ID(SentryAttachment)> *)
    processAttachmentsForEvent:(SentryEvent *)event
                   attachments:(NSArray<SENTRY_SWIFT_MIGRATION_ID(SentryAttachment)> *)attachments;

- (void)addAttachmentProcessor:(SENTRY_SWIFT_MIGRATION_ID(
                                   id<SentryClientAttachmentProcessor>))attachmentProcessor;
- (void)removeAttachmentProcessor:(SENTRY_SWIFT_MIGRATION_ID(
                                      id<SentryClientAttachmentProcessor>))attachmentProcessor;

@end

@interface SentryClientInternal (ReplayAndFeedback)

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(capture(_:replayRecording:video:with:));

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SENTRY_SWIFT_MIGRATION_ID(SentryAttachment)> *)
                                      feedbackAttachments
                            scope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                     currentScope:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryScope))currentScope;

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SENTRY_SWIFT_MIGRATION_ID(SentryAttachment)> *)
                                      feedbackAttachments
                            scope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope;

@end

NS_ASSUME_NONNULL_END
