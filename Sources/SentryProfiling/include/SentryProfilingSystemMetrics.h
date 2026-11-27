#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfilingSystemMetrics : NSObject

@property (nonatomic, strong, readonly, nullable) NSNumber *cpuUsage;
@property (nonatomic, strong, readonly, nullable) NSNumber *memoryFootprintBytes;
@property (nonatomic, strong, readonly, nullable) NSNumber *cpuEnergyUsage;

- (instancetype)initWithCPUUsage:(NSNumber *_Nullable)cpuUsage
            memoryFootprintBytes:(NSNumber *_Nullable)memoryFootprintBytes
                  cpuEnergyUsage:(NSNumber *_Nullable)cpuEnergyUsage;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
