#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@end

@implementation SentryUIDeviceWrapper

#if TARGET_OS_IOS

- (void)start
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchOnMainQueue:^{
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
    BOOL needsCleanUp = self.cleanupDeviceOrientationNotifications;
    BOOL needsDisablingBattery = self.cleanupBatteryMonitoring;

    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchOnMainQueue:^{
        if (needsCleanUp) {
            [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
        }
        if (needsDisablingBattery) {
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
