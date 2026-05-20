#import <Foundation/Foundation.h>
#import "SOCSentryFeedbackSource.h"

@class SOCSentryId;
@class SOCSentryAttachment;

NS_ASSUME_NONNULL_BEGIN

/// User feedback gathered manually and forwarded to Sentry.
@interface SOCSentryFeedback : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithMessage:(NSString *)message
                            name:(nullable NSString *)name
                           email:(nullable NSString *)email
                          source:(SOCSentryFeedbackSource)source
               associatedEventId:(nullable SOCSentryId *)associatedEventId
                     attachments:(nullable NSArray<SOCSentryAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
