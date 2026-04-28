#import <Foundation/Foundation.h>

#import "SentryFeedbackSource.h"

@class SentryAttachment;
@class SentryId;

NS_ASSUME_NONNULL_BEGIN

/**
 * User feedback submission.
 */
@interface SentryFeedback : NSObject

@property (nonatomic, readonly, strong) SentryId *eventId;

- (instancetype)initWithMessage:(NSString *)message
                           name:(nullable NSString *)name
                          email:(nullable NSString *)email
                         source:(SentryFeedbackSource)source
              associatedEventId:(nullable SentryId *)associatedEventId
                    attachments:(nullable NSArray<SentryAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
