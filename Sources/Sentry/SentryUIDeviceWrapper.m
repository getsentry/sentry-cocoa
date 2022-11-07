#import "SentryUIDeviceWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@end

@implementation SentryUIDeviceWrapper

#if TARGET_OS_IOS

- (instancetype)init
{
    if (self = [super init]) {
        [self executeOnMainThread:^{
            // Needed to read the device orientation on demand
            if (!UIDevice.currentDevice.isGeneratingDeviceOrientationNotifications) {
                self.cleanupDeviceOrientationNotifications = YES;
                [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
            }

            // Needed so we can read the battery level
            if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
                self.cleanupBatteryMonitoring = YES;
                UIDevice.currentDevice.batteryMonitoringEnabled = YES;
            }
        }];
    }
    return self;
}

- (void)dealloc
{
    [self executeOnMainThread:^{
        if (self.cleanupDeviceOrientationNotifications) {
            [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
        }
        if (self.cleanupBatteryMonitoring) {
            UIDevice.currentDevice.batteryMonitoringEnabled = NO;
        }
    }];
}

- (UIDeviceOrientation)orientation
{
    return UIDevice.currentDevice.orientation;
}

- (BOOL)isBatteryMonitoringEnabled
{
    return UIDevice.currentDevice.isBatteryMonitoringEnabled;
}

- (UIDeviceBatteryState)batteryState
{
    return UIDevice.currentDevice.batteryState;
}

- (float)batteryLevel
{
    return UIDevice.currentDevice.batteryLevel;
}

- (void)executeOnMainThread:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

#endif

@end

NS_ASSUME_NONNULL_END
