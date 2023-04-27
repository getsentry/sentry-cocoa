#import "SentrySystemWrapper.h"
#import "SentryError.h"
#import <mach/mach.h>

@implementation SentrySystemWrapper

/*
 * from https://developer.apple.com/forums/thread/91160
 *  powerInfo.task_energy is the total energy used by all threads
 *  - returned by calling task_info with TASK_POWER_INFO_V2
 *  - which calls task_power_info_locked
 *  - calculated by task_energy() (defined in darwin-xnu/osfmk/kern/task.c)
 *  - using ml_energy_stat (defined in darwin-xnu/osfmk/arm64/machine_routines.c)
 *  - which returns (thread_t)t->machine.energy_estimate_nj
 *
 * darwin-xnu/tests/task_info.c uses TASK_POWER_INFO_V2_COUNT for the size parameter
 *
 * TODO: can this be done per thread like the implementation of task_energy does? how to import the
 * kernel calls?
 */
- (NSArray<NSNumber *> *_Nullable)powerUsage:(NSError **)error
{
    struct task_power_info_v2 powerInfo;

    mach_msg_type_number_t size = TASK_POWER_INFO_V2_COUNT;

    task_t task = mach_task_self();
    kern_return_t kr = task_info(task, TASK_POWER_INFO_V2, (task_info_t)&powerInfo, &size);
    if (kr != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"Error with task_info(…TASK_POWER_INFO_V2…).", kr);
        }
        return nil;
    }

    return @[
        @(powerInfo.task_energy),
        @(powerInfo.cpu_energy.total_user + powerInfo.cpu_energy.total_system),
        @(powerInfo.gpu_energy.task_gpu_utilisation), @(powerInfo.task_ptime),
        @(powerInfo.task_pset_switches)
    ];
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

- (nullable NSNumber *)numContextSwitches:(NSError **)error
{
    task_events_info info;
    mach_msg_type_number_t count = TASK_EVENTS_INFO_COUNT;
    const auto status = task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_info reported an error.", status);
        }
        return 0;
    }
    return @(info.csw);
}

@end
