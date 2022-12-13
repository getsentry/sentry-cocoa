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

- (void)monitorForPowerStateChanges:(id)observer callback:(SEL)callback
{
    // According to Apple docs: "This notification is posted on the global dispatch queue. The
    // object associated with the notification is NSProcessInfo.processInfo." See the declaration
    // for NSProcessInfoPowerStateDidChangeNotification in NSProcessInfo.h for more information.
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:observer
           selector:callback
               name:NSProcessInfoPowerStateDidChangeNotification
             object:NSProcessInfo.processInfo];
}

- (void)monitorForThermalStateChanges:(id)observer callback:(SEL)callback
{
    // According to Apple docs: "This notification is posted on the global dispatch queue. The
    // object associated with the notification is NSProcessInfo.processInfo." See the declaration
    // for NSProcessInfoThermalStateDidChangeNotification in NSProcessInfo.h for more information.
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:observer
           selector:callback
               name:NSProcessInfoThermalStateDidChangeNotification
             object:NSProcessInfo.processInfo];
}

- (void)stopMonitoring:(id)observer
{
    const auto notifier = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    [notifier removeObserver:observer
                        name:NSProcessInfoThermalStateDidChangeNotification
                      object:NSProcessInfo.processInfo];
    [notifier removeObserver:observer
                        name:NSProcessInfoPowerStateDidChangeNotification
                      object:NSProcessInfo.processInfo];
}

@end
