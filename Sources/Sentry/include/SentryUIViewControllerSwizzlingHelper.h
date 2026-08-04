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
 * Installs a funnel on the base @c UIViewController designated initializers
 * (@c initWithNibName:bundle: and @c initWithCoder: ). After each initializer runs, the funnel
 * calls the handler synchronously with the concrete class of the just-initialized instance, so the
 * SDK can defer per-subclass lifecycle swizzling to first instantiation.
 *
 * Deferring avoids realizing @c \@available -gated subclasses on OS versions below their gate: a
 * class is only swizzled once an instance exists, which means the OS already realized it safely.
 *
 * @warning Experimental. Only installed when
 * @c options.experimental.enableUIViewControllerInitSwizzling is enabled, which is off by default.
 * See GH-8548.
 *
 * @param handler Invoked with the concrete class of every initialized @c UIViewController. Pass
 * @c nil (via @c stop ) to disable the funnel.
 */
+ (void)swizzleUIViewControllerInitsWithSubclassHandler:(void (^)(Class cls))handler;

+ (void)stop;

#    if SENTRY_TEST || SENTRY_TEST_CI

/**
 * Restores the base @c UIViewController @c loadView . Per-subclass lifecycle swizzles and the init
 * funnel stay installed, but @c stop makes them pass-throughs. Only available in test targets.
 */
+ (void)unswizzle;

/**
 * Returns whether swizzling is currently active. Only available in test targets.
 */
+ (BOOL)swizzlingActive;
#    endif

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
