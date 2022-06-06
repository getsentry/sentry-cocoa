#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryBenchmarking : NSObject

/** Begin a Sentry transaction, starting the profiler components. */
+ (void)startBenchmarkProfile;

/**
 * @return The % CPU overhead incurred by running the sampling profiler in the Sentry SDK in the
 * test app.
 * */
+ (double)retrieveBenchmarks;

@end

NS_ASSUME_NONNULL_END
