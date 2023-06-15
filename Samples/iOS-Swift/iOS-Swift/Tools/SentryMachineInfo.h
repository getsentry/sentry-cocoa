#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryCPUInfo : NSObject
@property uint64_t availableLogicalCores;
@property uint64_t enabledLogicalCores;
@property uint64_t availablePhysicalCores;
@property uint64_t enabledPhysicalCores;

@property uint64_t performanceLevels;

@property NSArray *availableLogicalCoresPerPerformanceLevel;
@property NSArray *enabledLogicalCoresPerPerformanceLevel;
@property NSArray *availablePhysicalCoresPerPerformanceLevel;
@property NSArray *enabledPhysicalCoresPerPerformanceLevel;
@end

@interface SentryMachineInfo : NSObject

+ (nullable SentryCPUInfo *)cpuInfo:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
