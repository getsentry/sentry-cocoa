#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/**
 * Notification posted when the device detects a shake gesture.
 * Subscribe to this notification to be informed when the user shakes the device.
 */
SENTRY_EXTERN NSNotificationName const SentryShakeDetectedNotification;

/**
 * Detects shake gestures by swizzling @c UIWindow 's @c motionEnded:withEvent: method.
 * When a shake gesture is detected, posts a @c SentryShakeDetectedNotification notification.
 *
 * Use @c +enable to start detection and @c +disable to stop it.
 * Swizzling is performed at most once regardless of how many times @c +enable is called.
 */
@interface SentryShakeDetector : NSObject

/**
 * Enables shake gesture detection. Swizzles @c UIWindow 's @c motionEnded:withEvent: method
 * the first time it is called, and from then on posts @c SentryShakeDetectedNotification
 * whenever a shake is detected.
 */
+ (void)enable;

/**
 * Disables shake gesture detection. Does not un-swizzle @c UIWindow ; it only suppresses
 * the notification so the overhead is negligible.
 */
+ (void)disable;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS
