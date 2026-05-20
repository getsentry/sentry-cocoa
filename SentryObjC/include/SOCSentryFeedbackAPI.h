#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// API for showing/hiding the in-app feedback widget. iOS only.
@interface SOCSentryFeedbackAPI : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)showWidget NS_EXTENSION_UNAVAILABLE_IOS("Not available in app extensions");
- (void)hideWidget NS_EXTENSION_UNAVAILABLE_IOS("Not available in app extensions");

@end

NS_ASSUME_NONNULL_END
