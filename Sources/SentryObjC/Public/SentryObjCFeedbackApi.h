#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

@class UIImage;
@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

/// API for interacting with the User Feedback feature.
@interface SentryObjCFeedbackApi : NSObject
SENTRY_NO_INIT

/**
 * Show the feedback form using the best available presenter.
 * @note This method must be called from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)show NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

/**
 * Show the feedback form using the best available presenter.
 * @param screenshot An optional screenshot to attach to the feedback form.
 * @note This method must be called from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)showWithScreenshot:(nullable UIImage *)screenshot
    NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

/**
 * Creates a feedback form view controller using the global User Feedback configuration.
 * @note Create and present this view controller from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
- (UIViewController *)formViewController NS_EXTENSION_UNAVAILABLE(
    "Not available in app extensions.");

/**
 * Creates a feedback form view controller using the global User Feedback configuration.
 * @param screenshot An optional screenshot to attach to the feedback form.
 * @note Create and present this view controller from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
- (UIViewController *)formViewControllerWithScreenshot:(nullable UIImage *)screenshot
    NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

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
