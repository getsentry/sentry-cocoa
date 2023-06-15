#import <Foundation/Foundation.h>

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

NS_ASSUME_NONNULL_BEGIN

/**
 * The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
@interface SentryCPUCoreReadings : NSObject
- (instancetype)initWithUsagePercentages:(NSArray<NSNumber *> *)usagePercentages;
@property NSArray<NSNumber *> *usagePercentages;
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
@property uint64_t systemTicks;
@property uint64_t userTicks;
@property uint64_t idleTicks;
- (uint64_t)total;
@end

/**
 * A structure to hold the results of comparing two benchmark readings from the start and end of a
 * benchmark session, plus the aggregated results of any sample-based readings.
 */
@interface SentryBenchmarkResult : NSObject
// MARK: start/end differences
@property int64_t cpuTicksSystem;
@property int64_t cpuTicksUser;
@property int64_t cpuTicksIdle;

@property int64_t cpuPower;
@property int64_t gpuPower;

@property int64_t contextSwitches;

// MARK: sample-based aggregations
@property SentryCPUCoreReadings *cpuUsagePerCore;
@property NSDictionary<NSString *, NSArray<NSNumber *> *> *cpuUsagePerThread;

/**
 * Compare two sets of results of benchmark comparisons.
 *
 * Say you benchmark an operation A with a certain implementation, and then a variant B with a
 * different implementation. Once you calculate the
 *
 * self - other
 */
- (SentryBenchmarkResult *)diff:(SentryBenchmarkResult *)other;
@end

/**
 * A structure that holds all the different readings taken at a moment in time.
 */
@interface SentryBenchmarkReading : NSObject
@property SentryCPUReading *cpuReading;
@property SentryPowerReading *powerReading;
@property uint64_t contextSwitches;

- (instancetype)initWithCPUTickInfo:(SentryCPUReading *)cpuTickInfo
                         powerUsage:(SentryPowerReading *)powerUsage
                    contextSwitches:(uint64_t)contextSwitches;

/**
 * Given two readings of various cumulative measurements, take the difference to find the "overhead"
 * of a measured operation. Essentially, end - start.
 *
 * self - other
 */
- (SentryBenchmarkResult *)diff:(SentryBenchmarkReading *)other;
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

+ (SentryBenchmarkReading *)gatherBenchmarkStats;

@end

NS_ASSUME_NONNULL_END
