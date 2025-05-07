#import <Foundation/Foundation.h>

#import "SentryPerformanceTracker.h"

#if SENTRY_HAS_UIKIT
#    import "SentryUIViewControllerPerformanceTracker.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * This wrapper class is used as a bridge to expose the ``SentryDependencyContainer`` to
 * `SentrySwift` and `SentrySwiftUI`.
 *
 * Due to unclear compilation errors, we can't import `SentryDependencyContainer` directly into
 * `SentrySwift` and `SentrySwiftUI`.
 */
@interface SentryDependencyContainerInternalBridge : NSObject

+ (SentryPerformanceTracker *)getPerformanceTracker;
#if SENTRY_HAS_UIKIT
+ (SentryUIViewControllerPerformanceTracker *)getUiViewControllerPerformanceTracker;
#endif

@end

NS_ASSUME_NONNULL_END
