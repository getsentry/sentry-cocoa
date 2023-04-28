#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#import <mach/mach.h>

NS_ASSUME_NONNULL_BEGIN

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

typedef void (^SentryMemoryPressureNotification)(uintptr_t);

/**
 * @c mach_vm_size_t Is a type defined in mach headers as an unsigned 64-bit type used to express
 * the amount of working memory the process currently has allocated.
 */
typedef mach_vm_size_t SentryRAMBytes;

@interface SentryCPUUsagePerCore : NSObject
- (instancetype)initWithUsages:(NSArray<NSNumber *> *)usages;
@property NSArray<NSNumber *> *usages;
@end

@interface SentryPowerUsageStats : NSObject
@property struct task_power_info_v2 info;
- (uint64_t)totalCPU;
- (uint64_t)totalGPU;
@end

@interface SentryThreadCPUUsage : NSObject
@property thread_basic_info_data_t data;
@end

@interface SentryCPUUsagePerThread : NSObject
@property NSMutableDictionary<NSNumber *, SentryThreadCPUUsage *> *usages;
@end

@interface SentryCPUTickInfo : NSObject
@property uint64_t system;
@property uint64_t user;
@property uint64_t idle;
- (uint64_t)total;
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
@end

/**
 * A wrapper around low-level system APIs that are found in headers such as @c <sys/...> and
 * @c <mach/...>.
 */
@interface SentrySystemWrapper : NSObject

- (SentryRAMBytes)memoryFootprintBytes:(NSError **)error;

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
- (nullable SentryCPUUsagePerCore *)cpuUsagePerCore:(NSError **)error;

/**
 * Return the current estimated amount of nanojoules used by the current mach task.
 * @returns An array with ordered values of [ total_energy, cpu_energy, gpu_energy, ptime, pswitches
 * ].
 */
- (nullable SentryPowerUsageStats *)powerUsage:(NSError **)error;

- (nullable NSNumber *)numContextSwitches:(NSError **)error;

- (nullable SentryCPUUsagePerThread *)cpuUsagePerThread:(NSError **)error;

- (nullable SentryCPUTickInfo *)cpuTicks:(NSError **)error;

- (nullable SentryCPUInfo *)cpuInfo:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
