#import <Foundation/Foundation.h>
#import <mach/host_info.h>
#import <mach/thread_info.h>

NS_ASSUME_NONNULL_BEGIN

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

@interface SentryThreadBasicInfo : NSObject
@property struct thread_basic_info threadInfo;
@end

/**
 * The amount of power that's been consumed since system boot at the moment the info is gathered.
 */
@interface SentryPowerReading : NSObject
@property struct task_power_info_v2 info;
- (uint64_t)totalCPU;
- (uint64_t)totalGPU;
@end

/**
 * The amount of ticks that have occurred since system boot at the moment the info is gathered.
 */
@interface SentryCPUReading : NSObject

/**
 * Only used to hold data as it is read; not used to hold results calculations. For results, see the
 * other properties.
 */
@property host_cpu_load_info_data_t data;

// MARK: extracted/calculated results

@property uint64_t systemTicks;
@property uint64_t userTicks;
@property uint64_t idleTicks;
- (uint64_t)total;
@end

/**
 * A structure that holds a sample of data that is expected to monotonically increase for a fixed
 * number of datapoints throughout the benchmark, so that only a start and end sample are needed and
 * the difference can be taken to compute the result.
 */
@interface SentryBenchmarkReading : NSObject
@property SentryCPUReading *cpu;
@property SentryPowerReading *power;
@property uint64_t contextSwitches;
@end

/**
 * For data that must be sampled because there are a variable amount of data points (threads may be
 * created or destroyed during the benchmark) or cannot be summed (like CPU usage percentage), a
 * wrapper around one reading at a moment in time.
 */
@interface SentryBenchmarkSample : NSObject
@property NSDictionary<NSString *, SentryThreadBasicInfo *> *threadInfos;
@property NSArray<NSNumber *> *cpuUsagePerCore;
@end

/**
 * The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
@interface SentrySampledBenchmarkResults : NSObject
@property NSArray<SentryBenchmarkSample *> *allSamples;
@property NSArray<NSNumber *> *aggregatedCPUUsagePerCore;
@property NSDictionary<NSString *, SentryThreadBasicInfo *> *aggregatedThreadInfo;
@end

/**
 * A structure to hold the results of comparing two benchmark readings from the start and end of a
 * benchmark session, plus the aggregated results of any sample-based readings.
 */
@interface SentryBenchmarkResult : NSObject
@property SentryBenchmarkReading *results;
@property SentrySampledBenchmarkResults *sampledResults;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithStart:(SentryBenchmarkReading *)start
                          end:(SentryBenchmarkReading *)end
       aggregatedSampleResult:(SentrySampledBenchmarkResults *)aggregatedSampleResult;
@end

@interface SentryBenchmarking : NSObject

/**
 * Gather some initial readings on system components and spin up an in-app sampling
 * profiler to gather information on per-thread CPU usages throughout the benchmark.
 */
+ (void)start;

/**
 * Return statistics on CPU usage by the profiler and test app for
 * downstream processing.
 * @return A dictionary serialized to a string, containing the values for profiler system time,
 * profiler user time, app system time and app user time, which can be used to calculate the
 * overhead of the profiler; or, if an error occurred, returns @c nil .
 */
+ (nullable NSString *)stopAndReturnProfilerThreadUsage;

/**
 * Gather final readings and return their diff, along with the aggregated results from
 * sampling-based data like per-thread CPU time.
 */
+ (SentryBenchmarkResult *)stop;

@end

NS_ASSUME_NONNULL_END
