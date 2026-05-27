#import <Foundation/Foundation.h>
#if SWIFT_PACKAGE
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// API for interacting with the User Feedback feature.
@interface SentryObjCFeedbackApi : NSObject

/**
 * Show the feedback widget button.
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)showWidget NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

/**
 * Hide the feedback widget button.
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)hideWidget NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

@end

NS_ASSUME_NONNULL_END

#endif
