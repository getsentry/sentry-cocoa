#import "SentryProfilingSystemMetrics.h"

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
