#import "SentrySystemEventBreadcrumbs.h"
#import "SentryBreadcrumb.h"
#import "SentryLog.h"
#import "SentrySDK.h"
#import "SentryDependencyContainer.h"
#import "SentryAppStateManager.h"
#import "SentryAppState.h"

// all those notifications are not available for tvOS
#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>
#endif

@implementation SentrySystemEventBreadcrumbs

- (void)start
{
#if TARGET_OS_IOS
    UIDevice *currentDevice = [UIDevice currentDevice];
    [self start:currentDevice];
#else
    [self initTimezoneObserver];
#endif
}

- (void)stop
{
#if TARGET_OS_IOS
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter removeObserver:self];
#endif
}

#if TARGET_OS_IOS
/**
 * Only used for testing, call start() instead.
 */
- (void)start:(UIDevice *)currentDevice
{
    if (currentDevice != nil) {
        [self initBatteryObserver:currentDevice];
        [self initOrientationObserver:currentDevice];
    } else {
        [SentryLog logWithMessage:@"currentDevice is null, it won't be able to record breadcrumbs "
                                  @"for device battery and orientation."
                         andLevel:kSentryLevelDebug];
    }
    [self initKeyboardVisibilityObserver];
    [self initScreenshotObserver];
    [self initTimezoneObserver];
}
#endif

#if TARGET_OS_IOS
- (void)initBatteryObserver:(UIDevice *)currentDevice
{
    if (currentDevice.batteryMonitoringEnabled == NO) {
        currentDevice.batteryMonitoringEnabled = YES;
    }

    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

    // Posted when the battery level changes.
    [defaultCenter addObserver:self
                      selector:@selector(batteryStateChanged:)
                          name:UIDeviceBatteryLevelDidChangeNotification
                        object:currentDevice];
    // Posted when battery state changes.
    [defaultCenter addObserver:self
                      selector:@selector(batteryStateChanged:)
                          name:UIDeviceBatteryStateDidChangeNotification
                        object:currentDevice];
}

- (void)batteryStateChanged:(NSNotification *)notification
{
    // Notifications for battery level change are sent no more frequently than once per minute
    NSMutableDictionary<NSString *, id> *batteryData = [self getBatteryStatus:notification.object];
    batteryData[@"action"] = @"BATTERY_STATE_CHANGE";

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.event"];
    crumb.type = @"system";
    crumb.data = batteryData;
    [SentrySDK addBreadcrumb:crumb];
}

- (NSMutableDictionary<NSString *, id> *)getBatteryStatus:(UIDevice *)currentDevice
{
    // borrowed and adapted from
    // https://github.com/apache/cordova-plugin-battery-status/blob/master/src/ios/CDVBattery.m
    UIDeviceBatteryState currentState = [currentDevice batteryState];

    BOOL isPlugged = NO; // UIDeviceBatteryStateUnknown or UIDeviceBatteryStateUnplugged
    if ((currentState == UIDeviceBatteryStateCharging)
        || (currentState == UIDeviceBatteryStateFull)) {
        isPlugged = YES;
    }
    float currentLevel = [currentDevice batteryLevel];
    NSMutableDictionary<NSString *, id> *batteryData = [NSMutableDictionary new];

    // W3C spec says level must be null if it is unknown
    if ((currentState != UIDeviceBatteryStateUnknown) && (currentLevel != -1.0)) {
        float w3cLevel = (currentLevel * 100);
        batteryData[@"level"] = @(w3cLevel);
    } else {
        [SentryLog logWithMessage:@"batteryLevel is unknown." andLevel:kSentryLevelDebug];
    }

    batteryData[@"plugged"] = @(isPlugged);
    return batteryData;
}

- (void)initOrientationObserver:(UIDevice *)currentDevice
{
    if (currentDevice.isGeneratingDeviceOrientationNotifications == NO) {
        [currentDevice beginGeneratingDeviceOrientationNotifications];
    }

    // Posted when the orientation of the device changes.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:currentDevice];
}

- (void)orientationChanged:(NSNotification *)notification
{
    UIDevice *currentDevice = notification.object;
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.orientation"];

    UIDeviceOrientation currentOrientation = currentDevice.orientation;

    // Ignore changes in device orientation if unknown, face up, or face down.
    if (!UIDeviceOrientationIsValidInterfaceOrientation(currentOrientation)) {
        [SentryLog logWithMessage:@"currentOrientation is unknown." andLevel:kSentryLevelDebug];
        return;
    }

    if (UIDeviceOrientationIsLandscape(currentOrientation)) {
        crumb.data = @{ @"position" : @"landscape" };
    } else {
        crumb.data = @{ @"position" : @"portrait" };
    }
    crumb.type = @"navigation";
    [SentrySDK addBreadcrumb:crumb];
}

- (void)initKeyboardVisibilityObserver
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    // Posted immediately after the display of the keyboard.
    [defaultCenter addObserver:self
                      selector:@selector(systemEventTriggered:)
                          name:UIKeyboardDidShowNotification
                        object:nil];

    // Posted immediately after the dismissal of the keyboard.
    [defaultCenter addObserver:self
                      selector:@selector(systemEventTriggered:)
                          name:UIKeyboardDidHideNotification
                        object:nil];
}

- (void)systemEventTriggered:(NSNotification *)notification
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.event"];
    crumb.type = @"system";
    crumb.data = @{ @"action" : notification.name };
    [SentrySDK addBreadcrumb:crumb];
}

- (void)initScreenshotObserver
{
    // it's only about the action, but not the SS itself
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(systemEventTriggered:)
                                                 name:UIApplicationUserDidTakeScreenshotNotification
                                               object:nil];
}
#endif

- (NSNumber *_Nullable)storedTimezoneOffset
{
    SentryAppStateManager *appStateManager = [SentryDependencyContainer sharedInstance].appStateManager;
    SentryAppState *currentState = [appStateManager loadCurrentAppState];
    return currentState.timezoneOffset;
}

- (void)initTimezoneObserver
{
    // Detect if the stored timezone is different from the current one;
    // if so, then we also send a breadcrumb
    NSNumber *_Nullable storedTimezoneOffset = [self storedTimezoneOffset];

    if (storedTimezoneOffset == nil) {
        [self updateStoredTimezone];
    } else if (storedTimezoneOffset.doubleValue != [NSTimeZone localTimeZone].secondsFromGMT) {
        [self timezoneEventTriggered];
    }

    // Posted when the timezone of the device changed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timezoneEventTriggered)
                                                 name:NSSystemTimeZoneDidChangeNotification
                                               object:nil];
}

- (void)timezoneEventTriggered
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.event"];
    crumb.type = @"system";
    crumb.data = @{
        @"action" : @"TIMEZONE_CHANGE",
        @"previous" : [self storedTimezoneOffset],
        @"new" : @([NSTimeZone localTimeZone].secondsFromGMT)
    };
    [SentrySDK addBreadcrumb:crumb];

    [self updateStoredTimezone];
}

- (void)updateStoredTimezone {
    SentryAppStateManager *appStateManager = [SentryDependencyContainer sharedInstance].appStateManager;
    [appStateManager updateAppState:^(SentryAppState *appState) {
        appState.timezoneOffset = @([NSTimeZone localTimeZone].secondsFromGMT);
    }];
}

@end
