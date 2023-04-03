#import "SentryExtraContextProvider.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryUIDeviceWrapper.h"

@interface
SentryExtraContextProvider ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryUIDeviceWrapper *deviceWrapper;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;

@end

@implementation SentryExtraContextProvider

+ (instancetype)sharedInstance
{
    static SentryExtraContextProvider *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (_Nonnull instancetype)init
{
    if (self = [super init]) {
        self.crashWrapper = [SentryCrashWrapper sharedInstance];
        self.deviceWrapper = [[SentryUIDeviceWrapper alloc] init];
        self.processInfoWrapper = [[SentryNSProcessInfoWrapper alloc] init];
    }
    return self;
}

- (NSDictionary *)getExtraContext
{
    NSMutableDictionary *extraContext = [[NSMutableDictionary alloc] init];

    [extraContext setValue:[self getExtraDeviceContext] forKey:@"device"];
    [extraContext setValue:[self getExtraAppContext] forKey:@"app"];

    return extraContext;
}

- (NSDictionary *)getExtraDeviceContext
{
    NSMutableDictionary *extraDeviceContext = [[NSMutableDictionary alloc] init];

    extraDeviceContext[SentryDeviceContextFreeMemoryKey] = @(self.crashWrapper.freeMemorySize);
    extraDeviceContext[@"free_storage"] = @(self.crashWrapper.freeStorageSize);
    extraDeviceContext[@"processor_count"] = @([self.processInfoWrapper processorCount]);

#if TARGET_OS_IOS
    if (self.deviceWrapper.orientation != UIDeviceOrientationUnknown) {
        extraDeviceContext[@"orientation"]
            = UIDeviceOrientationIsPortrait(self.deviceWrapper.orientation) ? @"portrait"
                                                                            : @"landscape";
    }

    if (self.deviceWrapper.isBatteryMonitoringEnabled) {
        extraDeviceContext[@"charging"]
            = self.deviceWrapper.batteryState == UIDeviceBatteryStateCharging ? @(YES) : @(NO);
        extraDeviceContext[@"battery_level"] = @((int)(self.deviceWrapper.batteryLevel * 100));
    }
#endif
    return extraDeviceContext;
}

- (NSDictionary *)getExtraAppContext
{
    NSMutableDictionary *extraAppContext = [[NSMutableDictionary alloc] init];
    extraAppContext[SentryDeviceContextAppMemoryKey] = @(self.crashWrapper.appMemorySize);
    return extraAppContext;
}

@end
