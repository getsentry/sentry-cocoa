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
 * @note Only the initializers are swizzled on the base class. The handler then swizzles lifecycle
 * methods on the concrete subclass, which ADDS a method when the subclass doesn't implement it,
 * while still inside the outermost initializer frame. That is the mechanism GH-1361 blamed for
 * GH-1355, and it could not be reproduced as a crash on any currently installable OS. See the
 * implementation comment for the evidence and its limits.
 *
 * @warning Experimental. Only installed when
 * @c options.experimental.enableUIViewControllerInitSwizzling is enabled, which is off by default.
 * See GH-8548.
 *
 * @param handler Invoked with the concrete class of every initialized @c UIViewController. Pass
 * @c nil (via @c stop ) to disable the funnel.
 */
+ (void)swizzleUIViewControllerInitsWithInitHandler:(void (^)(Class cls))handler;

+ (void)stop;

#    if SENTRY_TEST || SENTRY_TEST_CI

/**
 * Restores everything swizzled on the base @c UIViewController : @c loadView and the two init
 * funnel initializers. Restoring the initializers matters because a live base-class IMP outlives
 * the handler that @c stop clears, so leaving them installed leaks the funnel into every later test
 * suite in the same run. Per-subclass lifecycle swizzles stay installed, but @c stop makes them
 * pass-throughs. Only available in test targets.
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
