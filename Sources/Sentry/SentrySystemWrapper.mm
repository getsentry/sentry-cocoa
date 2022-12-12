#import "SentrySystemWrapper.h"
#import "SentryError.h"
#import "SentryMachLogging.hpp"
#import <mach/mach.h>

@implementation SentrySystemWrapper {
    dispatch_source_t _memoryWarningSource;
    dispatch_queue_t _memoryWarningQueue;
}

- (SentryRAMBytes)memoryFootprintBytes:(NSError *__autoreleasing _Nullable *)error
{
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;

    const auto status = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_info reported an error.", status);
        }
        return 0;
    }

    SentryRAMBytes footprintBytes;
    if (count >= TASK_VM_INFO_REV1_COUNT) {
        footprintBytes = info.phys_footprint;
    } else {
        footprintBytes = info.resident_size;
    }

    return footprintBytes;
}

- (NSArray<NSNumber *> *)cpuUsagePerCore:(NSError **)error
{
    natural_t numCPUs = 0U;
    processor_info_array_t cpuInfo;
    mach_msg_type_number_t numCPUInfo;
    const auto status = host_processor_info(
        mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"host_processor_info reported an error.", status);
        }
        return nil;
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:numCPUs];
    for (natural_t core = 0U; core < numCPUs; ++core) {
        const auto indexBase = CPU_STATE_MAX * core;
        const float user = cpuInfo[indexBase + CPU_STATE_USER];
        const float sys = cpuInfo[indexBase + CPU_STATE_SYSTEM];
        const float nice = cpuInfo[indexBase + CPU_STATE_NICE];
        const float idle = cpuInfo[indexBase + CPU_STATE_IDLE];
        const auto inUse = user + sys + nice;
        const auto total = inUse + idle;
        const auto usagePercent = inUse / total * 100.f;
        [result addObject:@(usagePercent)];
    }

    return result;
}

- (void)registerMemoryPressureNotifications:(SentryMemoryPressureNotification)handler
{
    const auto queueAttributes
        = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _memoryWarningQueue = dispatch_queue_create("io.sentry.queue.memory-warnings", queueAttributes);
    _memoryWarningSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
        DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN
            | DISPATCH_MEMORYPRESSURE_CRITICAL,
        _memoryWarningQueue);
    __weak auto weakSelf = self;
    dispatch_source_set_event_handler(_memoryWarningSource, ^{
        const auto strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        handler(dispatch_source_get_data(strongSelf->_memoryWarningSource));
    });
    dispatch_resume(_memoryWarningSource);
}

- (void)deregisterMemoryPressureNotifications
{
    dispatch_source_cancel(_memoryWarningSource);
}

@end
