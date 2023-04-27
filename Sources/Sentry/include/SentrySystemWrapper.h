#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

typedef void (^SentryMemoryPressureNotification)(uintptr_t);

/**
 * @c mach_vm_size_t Is a type defined in mach headers as an unsigned 64-bit type used to express
 * the amount of working memory the process currently has allocated.
 */
typedef mach_vm_size_t SentryRAMBytes;

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
- (nullable NSArray<NSNumber *> *)cpuUsagePerCore:(NSError **)error;

/**
 * Return the current estimated amount of nanojoules used by the current mach task.
 * @returns An array with ordered values of [ total_energy, cpu_energy, gpu_energy, ptime, pswitches
 * ].
 */
- (NSArray<NSNumber *> *_Nullable)powerUsage:(NSError **)error;

- (nullable NSNumber *)numContextSwitches:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
