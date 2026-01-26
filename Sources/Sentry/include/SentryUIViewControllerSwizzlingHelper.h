#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class that performs the actual method swizzling for UIViewController tracking.
 * This class is used by the Swift SentryUIViewControllerSwizzling class.
 */
@interface SentryUIViewControllerSwizzlingHelper : NSObject

/**
 * Swizzles the base UIViewController methods (loadView).
 */
+ (void)swizzleUIViewController;

/**
 * Swizzles a specific UIViewController subclass for performance tracking.
 * @param class The UIViewController subclass to swizzle.
 */
+ (void)swizzleViewControllerSubClass:(Class)class;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
