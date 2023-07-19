#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@property (strong, nonatomic) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@end

@implementation SentryUIDeviceWrapper

#if TARGET_OS_IOS

- (instancetype)init
{
    return [self initWithDispatchQueueWrapper:[SentryDependencyContainer sharedInstance]
                                                  .dispatchQueueWrapper];
}

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        UIDevice *device = [SENTRY_UIDevice currentDevice];
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        [self.dispatchQueueWrapper dispatchSyncOnMainQueue:^{
            // Needed to read the device orientation on demand
            if (!device.isGeneratingDeviceOrientationNotifications) {
                self.cleanupDeviceOrientationNotifications = YES;
                [device beginGeneratingDeviceOrientationNotifications];
            }

            // Needed so we can read the battery level
            if (!device.isBatteryMonitoringEnabled) {
                self.cleanupBatteryMonitoring = YES;
                UIDevice.currentDevice.batteryMonitoringEnabled = YES;
            }
        }];
    }
    return self;
}

- (void)stop
{
    [self.dispatchQueueWrapper dispatchSyncOnMainQueue:^{
        UIDevice *device = [SENTRY_UIDevice currentDevice];
        if (self.cleanupDeviceOrientationNotifications) {
            [device endGeneratingDeviceOrientationNotifications];
        }
        if (self.cleanupBatteryMonitoring) {
            device.batteryMonitoringEnabled = NO;
        }
    }];
}

- (void)dealloc
{
    [self stop];
}

- (SENTRY_UIDeviceOrientation)orientation
{
    return (SENTRY_UIDeviceOrientation)[SENTRY_UIDevice currentDevice].orientation;
}

- (BOOL)isBatteryMonitoringEnabled
{
    return [SENTRY_UIDevice currentDevice].isBatteryMonitoringEnabled;
}

- (SENTRY_UIDeviceBatteryState)batteryState
{
    return (SENTRY_UIDeviceBatteryState)[SENTRY_UIDevice currentDevice].batteryState;
}

- (float)batteryLevel
{
    return [SENTRY_UIDevice currentDevice].batteryLevel;
}

#endif

@end

NS_ASSUME_NONNULL_END
