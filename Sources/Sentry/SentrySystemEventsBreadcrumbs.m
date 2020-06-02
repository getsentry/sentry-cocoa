#import "SentrySystemEventsBreadcrumbs.h"
#import "SentrySDK.h"
#import "SentryLog.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@implementation SentrySystemEventsBreadcrumbs

- (void)start
{
#if SENTRY_HAS_UIKIT
    UIDevice *currentDevice = [UIDevice currentDevice];
    if (currentDevice == nil) {
        [SentryLog logWithMessage:@"currentDevice is null, it won't be able to record battery breadcrumbs."
                         andLevel:kSentryLogLevelDebug];
        return;
    }
    
    [self initBatteryObserver:currentDevice];
    [self initOrientationObserver:currentDevice];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentrySystemEventsBreadcrumbs.start] does nothing."
                     andLevel:kSentryLogLevelDebug];
#endif
}

- (void)initBatteryObserver:(UIDevice*)currentDevice
{
    if (currentDevice.batteryMonitoringEnabled == NO) {
        currentDevice.batteryMonitoringEnabled = YES;
    }
    
    // https://developer.apple.com/documentation/uikit/uidevicebatteryleveldidchangenotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:currentDevice];
    // https://developer.apple.com/documentation/uikit/uidevicebatterystatedidchangenotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:currentDevice];
    
    // add device battery breadcrumb on App. start
    [self addBatteryBreadcrumb:currentDevice];
    
    // for testing only
    //    [[NSNotificationCenter defaultCenter] postNotificationName:@"UIDeviceBatteryStateDidChangeNotification" object:currentDevice];
    //    [[NSNotificationCenter defaultCenter] postNotificationName:@"UIDeviceOrientationDidChangeNotification" object:currentDevice];
}

- (void)batteryStateChanged:(NSNotification*)notification
{
    UIDevice *currentDevice = notification.object;
    [self addBatteryBreadcrumb:currentDevice];
}

- (void)addBatteryBreadcrumb:(UIDevice*)currentDevice
{
    // Notifications for battery level change are sent no more frequently than once per minute
    NSDictionary* batteryData = [self getBatteryStatus:currentDevice];
    [batteryData setValue:@"BATTERY_STATE_CHANGE" forKey:@"action"];
    
    SentryBreadcrumb *crumb =
    [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                   category:@"device.event"];
    crumb.type = @"system";
    crumb.data = batteryData;
    [SentrySDK addBreadcrumb:crumb];
}

- (NSDictionary*)getBatteryStatus:(UIDevice*)currentDevice
{
    // borrowed and adapted from https://github.com/apache/cordova-plugin-battery-status/blob/master/src/ios/CDVBattery.m
    UIDeviceBatteryState currentState = [currentDevice batteryState];
    
    BOOL isPlugged = NO; // UIDeviceBatteryStateUnknown or UIDeviceBatteryStateUnplugged
    if ((currentState == UIDeviceBatteryStateCharging) || (currentState == UIDeviceBatteryStateFull)) {
        isPlugged = YES;
    }
    float currentLevel = [currentDevice batteryLevel];
    
    NSMutableDictionary *batteryData = [NSMutableDictionary new];
    
    // W3C spec says level must be null if it is unknown
    if ((currentState != UIDeviceBatteryStateUnknown) || (currentLevel != -1.0)) {
        float w3cLevel = (currentLevel * 100);
        [batteryData setValue:[NSNumber numberWithFloat:w3cLevel] forKey:@"level"];
    } else {
        [SentryLog logWithMessage:@"batteryLevel is unknown."
                         andLevel:kSentryLogLevelDebug];
    }
    [batteryData setValue:[NSNumber numberWithBool:isPlugged] forKey:@"plugged"];
    
    return batteryData;
}

- (void)initOrientationObserver:(UIDevice*)currentDevice
{
    if (currentDevice.isGeneratingDeviceOrientationNotifications == NO) {
        [currentDevice beginGeneratingDeviceOrientationNotifications];
    }
    // https://developer.apple.com/documentation/uikit/uideviceorientationdidchangenotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceOrientationDidChangeNotification object:currentDevice];
    
    // add first orientation breadcrumb on App. start
    [self addOrientationBreadcrumb:currentDevice];
}

- (void)orientationChanged:(NSNotification*)notification
{
    UIDevice *currentDevice = notification.object;
    [self addOrientationBreadcrumb:currentDevice];
}

- (void)addOrientationBreadcrumb:(UIDevice*)currentDevice
{
    SentryBreadcrumb *crumb =
    [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                   category:@"device.orientation"];
    
    //TODO: look at https://github.com/apache/cordova-plugin-screen-orientation/blob/master/src/ios/CDVOrientation.m
    // it uses [UIApplication sharedApplication].statusBarOrientation as well, should we use it? maybe device orientation and screen/app orientation
    
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

@end
