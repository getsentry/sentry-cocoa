#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryMemoryPressureNotification)(uintptr_t);

/**
 * A wrapper around low-level system APIs that are found in headers such as @c <sys/...> and @c
 * <mach/...>.
 */
@interface SentrySystemWrapper : NSObject

- (mach_vm_size_t)memoryFootprintBytes:(NSError **)error;

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
- (nullable NSArray<NSNumber *> *)cpuUsagePerCore:(NSError **)error;

- (void)registerMemoryPressureNotifications:(SentryMemoryPressureNotification)handler;
- (void)deregisterMemoryPressureNotifications;

@end

NS_ASSUME_NONNULL_END
