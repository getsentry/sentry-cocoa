#import "SentryObjCDefines.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCFeedbackApi : NSObject

- (void)showWidget NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");
- (void)hideWidget NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

@end

NS_ASSUME_NONNULL_END

#endif
