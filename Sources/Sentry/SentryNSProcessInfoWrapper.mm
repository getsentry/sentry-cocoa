#import "SentryNSProcessInfoWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryNSNotificationCenterWrapper.h"

@implementation SentryNSProcessInfoWrapper

- (NSProcessInfoThermalState)thermalState
{
    return NSProcessInfo.processInfo.thermalState;
}

- (BOOL)isLowPowerModeEnabled
{
    return NSProcessInfo.processInfo.isLowPowerModeEnabled;
}

- (NSUInteger)processorCount
{
    return NSProcessInfo.processInfo.processorCount;
}

- (void)monitorForPowerStateChanges:(id)target callback:(SEL)callback
{
    // According to Apple docs: "This notification is posted on the global dispatch queue. The
    // object associated with the notification is NSProcessInfo.processInfo."
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:target
           selector:callback
               name:NSProcessInfoPowerStateDidChangeNotification
             object:NSProcessInfo.processInfo];
}

- (void)monitorForThermalStateChanges:(id)target callback:(SEL)callback
{
    // According to Apple docs: "This notification is posted on the global dispatch queue. The
    // object associated with the notification is NSProcessInfo.processInfo."
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:target
           selector:callback
               name:NSProcessInfoThermalStateDidChangeNotification
             object:NSProcessInfo.processInfo];
}

- (void)stopMonitoring:(id)target
{
    const auto notifier = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    [notifier removeObserver:target
                        name:NSProcessInfoThermalStateDidChangeNotification
                      object:NSProcessInfo.processInfo];
    [notifier removeObserver:target
                        name:NSProcessInfoPowerStateDidChangeNotification
                      object:NSProcessInfo.processInfo];
}

@end
