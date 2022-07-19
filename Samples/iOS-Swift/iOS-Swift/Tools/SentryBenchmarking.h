#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryBenchmarking : NSObject

/**
 * Start a Sentry transaction, which will start the profiler, and also spin up an in-app sampling
 * profiler to gather information on thread CPU usages throughout the benchmark.
 */
+ (void)startBenchmark;

/**
 * Stop the profiled transaction and return statistics on CPU usage by the profiler and test app for
 * downstream processing.
 * @return A dictionary serialized to a string, containing the values for profiler system time,
 * profiler user time, app system time and app user time, which can be used to calculate the
 * overhead of the profiler; or, if an error occurred, returns @c nil .
 */
+ (nullable NSString *)stopBenchmark;

@end

NS_ASSUME_NONNULL_END
