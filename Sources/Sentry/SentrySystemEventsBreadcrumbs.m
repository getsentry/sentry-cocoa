#import "SentrySystemEventsBreadcrumbs.h"
#import "SentrySDK.h"
#import "SentryLog.h"

// all those notifications are not available for tvOS
#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>
#endif

@implementation SentrySystemEventsBreadcrumbs

- (void)start
{
#if TARGET_OS_IOS
    UIDevice *currentDevice = [UIDevice currentDevice];
    [self start:currentDevice];
#else
    [SentryLog logWithMessage:@"NO iOS -> [SentrySystemEventsBreadcrumbs.start] does nothing."
                     andLevel:kSentryLogLevelDebug];
#endif
}

#if TARGET_OS_IOS
- (void)start:(UIDevice*)currentDevice {
    if (currentDevice != nil) {
        [self initBatteryObserver:currentDevice];
        [self initOrientationObserver:currentDevice];
    } else {
        [SentryLog logWithMessage:@"currentDevice is null, it won't be able to record breadcrumbs for device battery and orientation."
                         andLevel:kSentryLogLevelDebug];
    }
    [self initKeyboardVisibilityObserver];
    [self initScreenshotObserver];
}
#endif

#if TARGET_OS_IOS
- (void)initBatteryObserver:(UIDevice*)currentDevice
{
    if (currentDevice.batteryMonitoringEnabled == NO) {
        currentDevice.batteryMonitoringEnabled = YES;
    }
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    // https://developer.apple.com/documentation/uikit/uidevicebatteryleveldidchangenotification
    [defaultCenter addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:currentDevice];
    // https://developer.apple.com/documentation/uikit/uidevicebatterystatedidchangenotification
    [defaultCenter addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:currentDevice];
    
    // for testing only
    //    [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceBatteryLevelDidChangeNotification object:currentDevice];
}

- (void)batteryStateChanged:(NSNotification*)notification
{
    // Notifications for battery level change are sent no more frequently than once per minute
    NSMutableDictionary *batteryData = [self getBatteryStatus:notification.object];
    batteryData[@"action"] = @"BATTERY_STATE_CHANGE";
    
    SentryBreadcrumb *crumb =
    [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                   category:@"device.event"];
    crumb.type = @"system";
    crumb.data = batteryData;
    [SentrySDK addBreadcrumb:crumb];
}

- (NSMutableDictionary<NSString *, NSNumber *> *)getBatteryStatus:(UIDevice*)currentDevice
{
    // borrowed and adapted from https://github.com/apache/cordova-plugin-battery-status/blob/master/src/ios/CDVBattery.m
    UIDeviceBatteryState currentState = [currentDevice batteryState];
    
    BOOL isPlugged = NO; // UIDeviceBatteryStateUnknown or UIDeviceBatteryStateUnplugged
    if ((currentState == UIDeviceBatteryStateCharging) || (currentState == UIDeviceBatteryStateFull)) {
        isPlugged = YES;
    }
    float currentLevel = [currentDevice batteryLevel];
    NSMutableDictionary<NSString *, NSNumber *> *batteryData = [NSMutableDictionary new];
    
    // W3C spec says level must be null if it is unknown
    if ((currentState != UIDeviceBatteryStateUnknown) || (currentLevel != -1.0)) {
        float w3cLevel = (currentLevel * 100);
        batteryData[@"level"] = @(w3cLevel);
    } else {
        [SentryLog logWithMessage:@"batteryLevel is unknown."
                         andLevel:kSentryLogLevelDebug];
    }
    
    batteryData[@"plugged"] = @(isPlugged);
    return batteryData;
}

- (void)initOrientationObserver:(UIDevice*)currentDevice
{
    if (currentDevice.isGeneratingDeviceOrientationNotifications == NO) {
        [currentDevice beginGeneratingDeviceOrientationNotifications];
    }
    
    // https://developer.apple.com/documentation/uikit/uideviceorientationdidchangenotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:currentDevice];
    
    // test
    // [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:currentDevice];
}

- (void)orientationChanged:(NSNotification*)notification
{
    UIDevice *currentDevice = notification.object;
    SentryBreadcrumb *crumb =
    [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                   category:@"device.orientation"];
    
    UIDeviceOrientation currentOrientation = currentDevice.orientation;
    
    // Ignore changes in device orientation if unknown, face up, or face down.
    if (!UIDeviceOrientationIsValidInterfaceOrientation(currentOrientation)) {
        [SentryLog logWithMessage:@"currentOrientation is unknown."
                         andLevel:kSentryLogLevelDebug];
        return;
    }
    
    if (UIDeviceOrientationIsLandscape(currentOrientation)){
        crumb.data = @{ @"position": @"landscape"};
    }
    else {
        crumb.data = @{ @"position": @"portrait"};
    }
    crumb.type = @"navigation";
    [SentrySDK addBreadcrumb:crumb];
}

- (void)initKeyboardVisibilityObserver
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    // https://developer.apple.com/documentation/uikit/uikeyboarddidshownotification
    [defaultCenter addObserver:self selector:@selector(systemEventTriggered:) name:UIKeyboardDidShowNotification object:nil];
    
    // https://developer.apple.com/documentation/uikit/uikeyboarddidhidenotification
    [defaultCenter addObserver:self selector:@selector(systemEventTriggered:) name:UIKeyboardDidHideNotification object:nil];
    
    // test
    // [[NSNotificationCenter defaultCenter] postNotificationName:UIKeyboardDidHideNotification object:nil];
}

- (void)systemEventTriggered:(NSNotification*)notification
{
    SentryBreadcrumb *crumb =
    [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                   category:@"device.event"];
    crumb.type = @"system";
    crumb.data = @ { @"action" : notification.name };
    [SentrySDK addBreadcrumb:crumb];
}

- (void)initScreenshotObserver
{
    // https://developer.apple.com/documentation/uikit/uiapplicationuserdidtakescreenshotnotification
    // it's only about the action, but not the SS itself
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(systemEventTriggered:) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    
    // test
    // [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationUserDidTakeScreenshotNotification object:nil];
}
#endif

@end
