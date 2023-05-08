#import <Foundation/Foundation.h>

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

NS_ASSUME_NONNULL_BEGIN

@interface SentryCPUUsagePerCore : NSObject
- (instancetype)initWithUsages:(NSArray<NSNumber *> *)usages;
@property NSArray<NSNumber *> *usages;
- (SentryCPUUsagePerCore *)diff:(SentryCPUUsagePerCore *)other;
@end

@interface SentryPowerUsageStats : NSObject
@property struct task_power_info_v2 info;
- (uint64_t)totalCPU;
- (uint64_t)totalGPU;
- (SentryPowerUsageStats *)diff:(SentryPowerUsageStats *)other;
@end

@interface SentryCPUTickInfo : NSObject
@property uint64_t system;
@property uint64_t user;
@property uint64_t idle;
- (uint64_t)total;
- (SentryCPUTickInfo *)diff:(SentryCPUTickInfo *)other;
@end

@interface SentryCPUInfo : NSObject
@property uint64_t availableLogicalCores;
@property uint64_t enabledLogicalCores;
@property uint64_t availablePhysicalCores;
@property uint64_t enabledPhysicalCores;

@property uint64_t performanceLevels;

@property NSArray *availableLogicalCoresPerPerformanceLevel;
@property NSArray *enabledLogicalCoresPerPerformanceLevel;
@property NSArray *availablePhysicalCoresPerPerformanceLevel;
@property NSArray *enabledPhysicalCoresPerPerformanceLevel;

- (SentryCPUInfo *)diff:(SentryCPUInfo *)other;
@end

@interface SentryBenchmarkStats : NSObject
@property SentryCPUInfo *cpuInfo;
@property SentryCPUTickInfo *cpuTickInfo;
@property SentryPowerUsageStats *powerUsage;
@property SentryCPUUsagePerCore *cpuUsage;

/** self - other */
- (SentryBenchmarkStats *)diff:(SentryBenchmarkStats *)other;
@end

@interface SentryBenchmarking : NSObject

/**
 * Start a Sentry transaction, which will start the profiler, and also spin up an in-app sampling
 * profiler to gather information on thread CPU usages throughout the benchmark.
 */
+ (void)startSampledBenchmark;

/**
 * Stop the profiled transaction and return statistics on CPU usage by the profiler and test app for
 * downstream processing.
 * @return A dictionary serialized to a string, containing the values for profiler system time,
 * profiler user time, app system time and app user time, which can be used to calculate the
 * overhead of the profiler; or, if an error occurred, returns @c nil .
 */
+ (nullable NSString *)stopSampledBenchmark;

+ (SentryBenchmarkStats *)gatherBenchmarkStats;

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
+ (nullable SentryCPUUsagePerCore *)cpuUsagePerCore:(NSError **)error;

/**
 * Return the current estimated amount of nanojoules used by the current mach task.
 * @returns An array with ordered values of [ total_energy, cpu_energy, gpu_energy, ptime, pswitches
 * ].
 */
+ (nullable SentryPowerUsageStats *)powerUsage:(NSError **)error;

+ (nullable NSNumber *)numContextSwitches:(NSError **)error;

+ (nullable SentryCPUTickInfo *)cpuTicks:(NSError **)error;

+ (nullable SentryCPUInfo *)cpuInfo:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
