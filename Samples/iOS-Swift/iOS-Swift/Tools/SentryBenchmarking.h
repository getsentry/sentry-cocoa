#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryBenchmarking : NSObject

/**
 * Start a Sentry transaction, which will start the profiler, and also spin up an in-app sampling profiler to
 * gather information on thread CPU usages throughout the benchmark.
 */
+ (void)startBenchmark;

/**
 * Stop the profiled transaction and print statistics on CPU usage by the profiler and test app separately to
 * the console for downstream processing.
 * @return The calculated % overhead of the profiler vs. the rest of the app.
 */
+ (double)stopBenchmark;

@end

NS_ASSUME_NONNULL_END
