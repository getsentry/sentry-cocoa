#import "SentryProfilingSystemMetrics.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryProfilingSystemMetrics

- (instancetype)initWithCPUUsage:(NSNumber *_Nullable)cpuUsage
            memoryFootprintBytes:(NSNumber *_Nullable)memoryFootprintBytes
                  cpuEnergyUsage:(NSNumber *_Nullable)cpuEnergyUsage
{
    if (self = [super init]) {
        _cpuUsage = cpuUsage;
        _memoryFootprintBytes = memoryFootprintBytes;
        _cpuEnergyUsage = cpuEnergyUsage;
    }
    return self;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
