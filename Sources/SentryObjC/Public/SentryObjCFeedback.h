#import "SentryObjCFeedbackSource.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCAttachment;

NS_ASSUME_NONNULL_BEGIN

/// Represents a user feedback submission containing a message and optional contact information.
@interface SentryObjCFeedback : NSObject

/// The main feedback message content.
@property (nonatomic, readonly, copy) NSString *message;

/// The name of the user submitting feedback.
@property (nonatomic, readonly, copy, nullable) NSString *name;

/// The email address of the user submitting feedback.
@property (nonatomic, readonly, copy, nullable) NSString *email;

/// The source of the feedback (e.g. widget or custom).
@property (nonatomic, readonly) SentryObjCFeedbackSource source;

/// The unique event identifier for this feedback submission.
@property (nonatomic, readonly, strong) SentryObjCId *eventId;

/// The event ID that this feedback is associated with, like a crash report.
@property (nonatomic, readonly, strong, nullable) SentryObjCId *associatedEventId;

/// Attachments for this feedback submission, like a screenshot.
@property (nonatomic, readonly, strong, nullable) NSArray<SentryObjCAttachment *> *attachments;

/**
 * Initializes a feedback instance with the specified parameters.
 * @param message The main feedback message content.
 * @param name The name of the user submitting feedback.
 * @param email The email address of the user submitting feedback.
 * @param source The source of the feedback (e.g. widget or custom).
 * @param associatedEventId The ID for an event you'd like associated with the feedback.
 * @param attachments Attachment objects for any files to include with the feedback.
 */
- (instancetype)initWithMessage:(NSString *)message
                           name:(nullable NSString *)name
                          email:(nullable NSString *)email
                         source:(SentryObjCFeedbackSource)source
              associatedEventId:(nullable SentryObjCId *)associatedEventId
                    attachments:(nullable NSArray<SentryObjCAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
