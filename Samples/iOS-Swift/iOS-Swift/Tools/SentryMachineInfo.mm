#import "SentryMachineInfo.h"
#import <sys/sysctl.h>

@implementation SentryCPUInfo

- (NSString *)debugDescription
{
    const auto result = [NSMutableString string];
    for (uint64_t perfLevel = 0; perfLevel < _performanceLevels; perfLevel++) {
        [result appendFormat:@"perf level %llu cores: physical max: %@; enabled: %@; logical max: "
                             @"%@; enabled: %@\n",
                perfLevel, _availablePhysicalCoresPerPerformanceLevel[perfLevel],
                _enabledPhysicalCoresPerPerformanceLevel[perfLevel],
                _availableLogicalCoresPerPerformanceLevel[perfLevel],
                _enabledLogicalCoresPerPerformanceLevel[perfLevel]];
    }
    return [result stringByReplacingCharactersInRange:NSMakeRange(result.length - 1, 1)
                                           withString:@""];
}

@end

@implementation SentryMachineInfo

+ (nullable SentryCPUInfo *)cpuInfo:(NSError **)error
{
#define SENTRY_SYSCTLBYNAME_ULL(name)                                                              \
    [self sysctlbynameWithName:"hw." name error:nil].unsignedLongLongValue
    const auto info = [[SentryCPUInfo alloc] init];
    info.availableLogicalCores = SENTRY_SYSCTLBYNAME_ULL("logicalcpu");
    info.enabledLogicalCores = SENTRY_SYSCTLBYNAME_ULL("logicalcpu_max");
    info.availablePhysicalCores = SENTRY_SYSCTLBYNAME_ULL("physicalcpu_max");
    info.enabledPhysicalCores = SENTRY_SYSCTLBYNAME_ULL("physicalcpu");

    info.performanceLevels = SENTRY_SYSCTLBYNAME_ULL("nperflevels");

    const auto availableLogicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
    const auto enabledLogicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
    const auto availablePhysicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
    const auto enabledPhysicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
#undef SENTRY_SYSCTLBYNAME_ULL

#define SENTRY_SYSCTLBYNAME_PERF(name, level)                                                      \
    [self sysctlbynameWithName:[NSString stringWithFormat:@"hw.perflevel%llu.%s", level, name]     \
                                   .UTF8String                                                     \
                         error:nil]
    for (uint64_t perfLevel = 0; perfLevel < info.performanceLevels; perfLevel++) {
        [availableLogicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("logicalcpu_max", perfLevel)];
        [enabledLogicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("logicalcpu", perfLevel)];
        [availablePhysicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("physicalcpu", perfLevel)];
        [enabledPhysicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("physicalcpu_max", perfLevel)];
    }
#undef SENTRY_SYSCTLBYNAME_PERF

    info.availableLogicalCoresPerPerformanceLevel = availableLogicalCoresPerPerformanceLevel;
    info.enabledLogicalCoresPerPerformanceLevel = enabledLogicalCoresPerPerformanceLevel;
    info.availablePhysicalCoresPerPerformanceLevel = availablePhysicalCoresPerPerformanceLevel;
    info.enabledPhysicalCoresPerPerformanceLevel = enabledPhysicalCoresPerPerformanceLevel;

    return info;
}

+ (nullable NSNumber *)sysctlbynameWithName:(const char *)name error:(NSError **)error
{
    int result;
    size_t resultSize = sizeof(result);
    const auto status = sysctlbyname(name, &result, &resultSize, NULL, 0);
    if (status != KERN_SUCCESS) {
        NSLog(@"error: %s; %d", strerror(errno), status);
        return nil;
    }

    return @(result);
}

@end
