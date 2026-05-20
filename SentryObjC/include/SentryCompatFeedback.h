#import <Foundation/Foundation.h>
#import "SentryCompatFeedbackSource.h"

@class SentryCompatId;
@class SentryCompatAttachment;

NS_ASSUME_NONNULL_BEGIN

/// User feedback gathered manually and forwarded to Sentry.
@interface SentryCompatFeedback : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithMessage:(NSString *)message
                            name:(nullable NSString *)name
                           email:(nullable NSString *)email
                          source:(SentryCompatFeedbackSource)source
               associatedEventId:(nullable SentryCompatId *)associatedEventId
                     attachments:(nullable NSArray<SentryCompatAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
