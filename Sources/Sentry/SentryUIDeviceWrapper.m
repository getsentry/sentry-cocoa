#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryThreadWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@end

@implementation SentryUIDeviceWrapper

#if TARGET_OS_IOS

- (void)start {
    [SentryThreadWrapper onMainThread:^{
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

- (void)stop
{
    [SentryThreadWrapper onMainThread:^{
        if (self.cleanupDeviceOrientationNotifications) {
            [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
        }
        if (self.cleanupBatteryMonitoring) {
            UIDevice.currentDevice.batteryMonitoringEnabled = NO;
        }
    }];
}

- (void)dealloc
{
    [self stop];
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

#endif

@end

NS_ASSUME_NONNULL_END
