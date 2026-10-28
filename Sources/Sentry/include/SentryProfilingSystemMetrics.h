#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfilingSystemMetrics : NSObject

@property (nonatomic, strong, readonly, nullable) NSNumber *cpuUsage;
@property (nonatomic, strong, readonly, nullable) NSNumber *memoryFootprintBytes;
@property (nonatomic, strong, readonly, nullable) NSNumber *cpuEnergyUsage;

- (instancetype)initWithCPUUsage:(NSNumber *_Nullable)cpuUsage
            memoryFootprintBytes:(NSNumber *_Nullable)memoryFootprintBytes
                  cpuEnergyUsage:(NSNumber *_Nullable)cpuEnergyUsage;
SENTRY_NO_INIT

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
