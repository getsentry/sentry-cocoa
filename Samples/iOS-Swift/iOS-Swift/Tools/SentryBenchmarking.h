#import <UIKit/UIKit.h>
#import <mach/host_info.h>
#import <mach/task_info.h>
#import <mach/thread_info.h>

NS_ASSUME_NONNULL_BEGIN

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

@interface SentryThreadBasicInfo : NSObject
- (nonnull instancetype)initForThread:(int)thread
                                error:(NSError *__autoreleasing _Nullable *_Nullable)error;
@property struct thread_basic_info threadInfo;
@end

/**
 * The amount of power that's been consumed since system boot at the moment the info is gathered.
 */
@interface SentryPowerReading : NSObject
- (instancetype)initWithError:(NSError **)error;
/** This structure as returned from @c task_info gives the amounts since process/device launch; we
 * take the difference between two staggered readings to calculate an "instantaneous" amount. */
@property struct task_power_info_v2 instantaneousInfo;
/** The raw result from calling @c task_info. For an "instantaneous" reading, use */
@property struct task_power_info_v2 cumulativeInfo;
/**
 * From @c UIDevice.batteryLevel
 * @warning: From docs: "Notifications for battery level change are sent no more frequently than
 * once per minute. Don’t attempt to calculate battery drainage rate or battery time remaining;
 * drainage rate can change frequently depending on built-in applications as well as your
 * application."
 * @note From docs: "-1.0 if UIDeviceBatteryStateUnknown"
 * @warning apparently setting batteryMonitoringEnabled YES from multiple threads can cause a crash
 */
@property float batteryLevel;
@property UIDeviceBatteryState batteryState;
/** From @c NSProcessInfo.lowPowerModeEnabled */
@property BOOL lowPowerModeEnabled;
/** From @c NSProcessInfo.thermalState */
@property NSProcessInfoThermalState thermalState;
- (uint64_t)totalInstantaneousCPU;
- (uint64_t)totalCumulativeCPU;
@end

@interface SentryTaskEventsReading : NSObject
- (instancetype)initWithError:(NSError **)error;
@property struct task_events_info data;
@end

/**
 * The amount of ticks that have occurred since system boot at the moment the info is gathered.
 */
@interface SentryCPUReading : NSObject
- (instancetype)initWithError:(NSError **)error;
@property uint64_t systemTicks;
@property uint64_t userTicks;
@property uint64_t idleTicks;
/** From @c NSProcessInfo.activeProcessorCount */
@property NSUInteger activeProcessorCount;

/** The amount of system and user ticks. */
- (uint64_t)totalTicks;
@end

/**
 * A structure that holds a sample of data that is expected to monotonically increase for a fixed
 * number of datapoints throughout the benchmark, so that only a start and end sample are needed and
 * the difference can be taken to compute the result.
 */
@interface SentryBenchmarkReading : NSObject
- (instancetype)initWithError:(NSError **)error;
@property uint64_t machTime;
@property NSDate *timestamp;
@property SentryCPUReading *cpu;
@property SentryPowerReading *power;
@property SentryTaskEventsReading *taskEvents;
@end

@interface SentryScreenReading : NSObject
- (instancetype)initWithError:(NSError **)error;
@property CGFloat displayBrightness;
/** A comment in UIScreen.h states this specifically can incur performance costs. */
@property BOOL wantsSoftwareDimming;
/** Screen is being captured, eg by AirPlay, mirroring etc. */
@property BOOL captured;
@end

/**
 * For data that must be sampled because there are a variable amount of data points (threads may be
 * created or destroyed during the benchmark) or cannot be summed (like CPU usage percentage), a
 * wrapper around one reading at a moment in time.
 */
@interface SentryBenchmarkSample : NSObject
@property uint64_t machTime;
@property NSDictionary<NSString *, SentryThreadBasicInfo *> *threadInfos;
/** */
@property NSArray<NSNumber *> *cpuUsagePerCore;
@property SentryPowerReading *power;
@property SentryScreenReading *device;
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

+ (instancetype)shared;

/**
 * Gather some initial readings on system components and spin up an in-app sampling
 * profiler to gather information on per-thread CPU usages throughout the benchmark.
 */
- (void)start;

/**
 * Return statistics on CPU usage by the profiler and test app for
 * downstream processing.
 * @return A dictionary serialized to a string, containing the values for profiler system time,
 * profiler user time, app system time and app user time, which can be used to calculate the
 * overhead of the profiler; or, if an error occurred, returns @c nil .
 */
- (nullable NSString *)stopAndReturnProfilerThreadUsage;

/**
 * Gather final readings and return their diff, along with the aggregated results from
 * sampling-based data like per-thread CPU time.
 */
- (SentryBenchmarkResult *)stop;

+ (uint64_t)machTime;

@end

NS_ASSUME_NONNULL_END
