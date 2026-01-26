#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class that performs the actual method swizzling for UIViewController tracking.
 * This class is used by the Swift SentryUIViewControllerSwizzling class.
 */
@interface SentryUIViewControllerSwizzlingHelper : NSObject

/**
 * Swizzles the base UIViewController methods (loadView) with the provided tracker.
 * @param tracker The performance tracker to use for tracking view controller lifecycle events.
 */
+ (void)swizzleUIViewControllerWithTracker:(SENTRY_SWIFT_MIGRATION_ID(
                                               SentryUIViewControllerPerformanceTracker))tracker;

/**
 * Swizzles a specific UIViewController subclass for performance tracking.
 * @param class The UIViewController subclass to swizzle.
 */
+ (void)swizzleViewControllerSubClass:(Class)class;

/**
 * Unswizzles all UIViewController methods. Only available in test targets.
 */
+ (void)unswizzle;

#    if SENTRY_TEST || SENTRY_TEST_CI
/**
 * Returns whether swizzling is currently active. Only available in test targets.
 */
+ (BOOL)swizzlingActive;
#    endif

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
