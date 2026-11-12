#import "SentrySDKInternal.h"

NS_ASSUME_NONNULL_BEGIN

// Arguments that use Swift attachment types are declared as id so Swift can import this header.

@interface SentrySDKInternal ()

+ (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SENTRY_SWIFT_MIGRATION_ID(SentryAttachment)> *)
                                      feedbackAttachments;

@end

NS_ASSUME_NONNULL_END
