#import "SentryUIDeviceWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@end

@implementation SentryUIDeviceWrapper

- (instancetype)init
{
    if (self = [super init]) {
#if TARGET_OS_IOS
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
#endif
    }
    return self;
}

- (void)dealloc
{
#if TARGET_OS_IOS
    if (self.cleanupDeviceOrientationNotifications) {
        [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
    }
    if (self.cleanupBatteryMonitoring) {
        UIDevice.currentDevice.batteryMonitoringEnabled = NO;
    }
#endif
}

#if TARGET_OS_IOS
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
#endif

@end

NS_ASSUME_NONNULL_END
