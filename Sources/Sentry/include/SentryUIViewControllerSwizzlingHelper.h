#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * Performs the method swizzling for UIViewController tracking on behalf of the Swift
 * SentryUIViewControllerSwizzling class.
 *
 * @warning Main thread only, and deliberately unsynchronized. Everything here swizzles
 * @c UIViewController lifecycle and initializer methods, which UIKit only calls on the main thread,
 * so the shared state below needs no locking. Calling any of this from a background thread races
 * that state and the ObjC runtime mutations.
 */
@interface SentryUIViewControllerSwizzlingHelper : NSObject

+ (void)swizzleUIViewControllerWithTracker:(SENTRY_SWIFT_MIGRATION_ID(
                                               SentryUIViewControllerPerformanceTracker))tracker;

+ (void)swizzleViewControllerSubClass:(Class)class;

/**
 * Swizzles the base @c UIViewController designated initializers and notifies @c delegate after each
 * one, so the caller can defer its own swizzling to first instantiation. Deferring avoids realizing
 * @c \@available -gated subclasses below their gate: a class is only reached once an instance
 * exists, which means the OS already realized it safely.
 *
 * @warning Experimental. Only installed when
 * @c options.experimental.enableUIViewControllerInitSwizzling is enabled, which is off by default.
 * See GH-8548.
 */
+ (void)swizzleUIViewControllerInitsWithDelegate:
    (SENTRY_SWIFT_MIGRATION_ID(SentryUIViewControllerInitSwizzlingDelegate))delegate;

+ (void)stop;

#    if SENTRY_TEST || SENTRY_TEST_CI

/**
 * Restores @c loadView and the two init funnel initializers. Restoring the initializers matters
 * because a live base-class IMP outlives the delegate that @c stop clears, so leaving them
 * installed leaks the funnel into every later test suite in the same run.
 */
+ (void)unswizzle;

+ (BOOL)swizzlingActive;
#    endif

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
