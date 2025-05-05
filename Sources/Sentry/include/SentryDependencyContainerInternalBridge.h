#import <Foundation/Foundation.h>

#import "SentryPerformanceTracker.h"

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

@end

NS_ASSUME_NONNULL_END
