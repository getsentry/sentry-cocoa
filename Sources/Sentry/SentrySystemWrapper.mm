#import "SentrySystemWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryError.h"
#import "SentryNSProcessInfoWrapper.h"
#import <mach/mach.h>
#include <thread>

@implementation SentrySystemWrapper {
    float processorCount;
}

- (instancetype)init
{
    if ((self = [super init])) {
        processorCount
            = (float)SentryDependencyContainer.sharedInstance.processInfoWrapper.processorCount;
    }
    return self;
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

- (NSNumber *)cpuUsageWithError:(NSError **)error
{
    mach_msg_type_number_t count;
    thread_act_array_t list;

    const auto taskThreadsStatus = task_threads(mach_task_self(), &list, &count);
    if (taskThreadsStatus != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_threads reported an error.", taskThreadsStatus);
        }
        return nil;
    }

    auto usage = 0.f;
    const auto threads = [NSMutableArray array];
    for (decltype(count) i = 0; i < count; i++) {
        const auto thread = list[i];

        mach_msg_type_number_t infoSize = THREAD_BASIC_INFO_COUNT;
        thread_basic_info_data_t data;
        // MACH_SEND_INVALID_DEST is returned when the thread no longer exists
        const auto threadInfoStatus = thread_info(
            thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &infoSize);
        if (threadInfoStatus != KERN_SUCCESS) {
            if (error) {
                *error = NSErrorFromSentryErrorWithKernelError(
                    kSentryErrorKernel, @"thread_info reported an error.", taskThreadsStatus);
            }
            return nil;
        }

        [threads addObject:@(data.cpu_usage)];
        usage += data.cpu_usage / processorCount;
    }

    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);

    NSLog(@"CPU usage: %f; per thread: %@", usage, [threads componentsJoinedByString:@", "]);

    return @(usage);
}

@end
