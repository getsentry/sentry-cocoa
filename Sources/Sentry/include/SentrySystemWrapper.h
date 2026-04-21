#import "SentryProfilerDefines.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

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

- (instancetype)initWithProcessorCount:(long)processorCount;

- (SentryRAMBytes)memoryFootprintBytes:(NSError **)error;

/**
 * @return The CPU usage of this process as a percentage of the device's total CPU capacity,
 * normalized to a range from @c 0.0 to @c 100.0.
 */
- (nullable NSNumber *)cpuUsageWithError:(NSError **)error;

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
/**
 * Test-only helper that normalizes a thread CPU usage value returned by Mach to the
 * process's percentage of the device's total CPU capacity.
 */
+ (float)normalizeCPUUsage:(integer_t)threadCPUUsage processorCount:(long)processorCount;
#    endif

// Only some architectures support reading energy.
#    if defined(__arm__) || defined(__arm64__)
/**
 * @return The cumulative amount of nanojoules expended by the CPU for this task since process
 * start.
 */
- (nullable NSNumber *)cpuEnergyUsageWithError:(NSError **)error;
#    endif

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
