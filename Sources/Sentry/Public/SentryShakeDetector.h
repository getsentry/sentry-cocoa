#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Notification posted when the device detects a shake gesture on iOS.
 * On non-iOS platforms this notification is never posted.
 */
SENTRY_EXTERN NSNotificationName const SentryShakeDetectedNotification;

/**
 * Detects shake gestures by swizzling @c UIWindow 's @c motionEnded:withEvent: method on iOS.
 * When a shake gesture is detected, posts a @c SentryShakeDetectedNotification notification.
 *
 * Use @c +enable to start detection and @c +disable to stop it.
 * Swizzling is performed at most once regardless of how many times @c +enable is called.
 * On non-iOS platforms (macOS, tvOS, watchOS), these methods are no-ops.
 */
@interface SentryShakeDetector : NSObject

/**
 * Enables shake gesture detection. On iOS, swizzles @c UIWindow 's @c motionEnded:withEvent:
 * the first time it is called, and from then on posts @c SentryShakeDetectedNotification
 * whenever a shake is detected. No-op on non-iOS platforms.
 */
+ (void)enable;

/**
 * Disables shake gesture detection. Does not un-swizzle @c UIWindow ; it only suppresses
 * the notification so the overhead is negligible. No-op on non-iOS platforms.
 */
+ (void)disable;

@end

NS_ASSUME_NONNULL_END
