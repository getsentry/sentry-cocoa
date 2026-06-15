#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

@class UIImage;
@class UIViewController;
@class SentryObjCUserFeedbackConfiguration;

NS_ASSUME_NONNULL_BEGIN

/// Factory namespace for creating User Feedback form view controllers.
///
/// This type is not a view controller. It only creates @c UIViewController instances for callers to
/// present from their own UI.
@interface SentryObjCFeedbackForm : NSObject
SENTRY_NO_INIT

/**
 * Creates a feedback form view controller using the global User Feedback configuration.
 * @note Create and present this view controller from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
+ (UIViewController *)viewController NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

/**
 * Creates a feedback form view controller using the global User Feedback configuration.
 * @param screenshot An optional screenshot to attach to the feedback form.
 * @note Create and present this view controller from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
+ (UIViewController *)viewControllerWithScreenshot:(nullable UIImage *)screenshot
    NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

/**
 * Creates a feedback form view controller using the global User Feedback configuration and
 * form-specific configuration.
 * @param configure A block to customize this feedback form presentation.
 * @note Per-presentation configuration only affects the displayed form. Widget, custom button,
 * screenshot trigger, and shake gesture settings are global and ignored for individual
 * presentations.
 * @note Create and present this view controller from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
+ (UIViewController *)viewControllerWithConfigure:
    (nullable void (^)(SentryObjCUserFeedbackConfiguration *configuration))configure
    NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

/**
 * Creates a feedback form view controller using the global User Feedback configuration, screenshot
 * attachment, and form-specific configuration.
 * @param screenshot An optional screenshot to attach to the feedback form.
 * @param configure A block to customize this feedback form presentation.
 * @note Per-presentation configuration only affects the displayed form. Widget, custom button,
 * screenshot trigger, and shake gesture settings are global and ignored for individual
 * presentations.
 * @note Create and present this view controller from the main thread.
 * @warning This is an experimental feature and may still have bugs.
 */
+ (UIViewController *)
    viewControllerWithScreenshot:(nullable UIImage *)screenshot
                       configure:(nullable void (^)(
                                     SentryObjCUserFeedbackConfiguration *configuration))configure
    NS_EXTENSION_UNAVAILABLE("Not available in app extensions.");

@end

NS_ASSUME_NONNULL_END

#endif
