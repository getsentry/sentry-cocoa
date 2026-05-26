#import "SentryObjCDefines.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCFeedbackApi : NSObject

- (void)showWidget API_UNAVAILABLE(ios_app_extension);
- (void)hideWidget API_UNAVAILABLE(ios_app_extension);

@end

NS_ASSUME_NONNULL_END

#endif
