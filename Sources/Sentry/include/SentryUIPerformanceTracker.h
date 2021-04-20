#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 * Class is responsible to swizzle UI key methods
 * so Sentry can track UI performance.
 */
@interface SentryUIPerformanceTracker : NSObject

+ (void)start;
@end

NS_ASSUME_NONNULL_END
