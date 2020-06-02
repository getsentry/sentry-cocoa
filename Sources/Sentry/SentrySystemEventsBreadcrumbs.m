#import "SentrySystemEventsBreadcrumbs.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentrySDK.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@implementation SentrySystemEventsBreadcrumbs

- (void)start
{
    [self initBatteryObserver];
}

- (void)initBatteryObserver
{
    UIDevice *device = [UIDevice currentDevice];
    
    if (device.batteryMonitoringEnabled == NO) {
        device.batteryMonitoringEnabled = YES;
    }
    
    // https://developer.apple.com/documentation/uikit/uidevicebatteryleveldidchangenotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryLevelDidChangeNotification" object:nil];
    // https://developer.apple.com/documentation/uikit/uidevicebatterystatedidchangenotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:nil];
    
    // for testing only
//    [[NSNotificationCenter defaultCenter] postNotificationName:@"UIDeviceBatteryStateDidChangeNotification" object:nil];
}

- (void)batteryStateChanged:(NSNotification*)notification
{
    // Notifications for battery level change are sent no more frequently than once per minute
    NSDictionary* batteryData = [self getBatteryStatus];
    [batteryData setValue:@"BATTERY_STATE_CHANGE" forKey:@"action"];
    
    SentryBreadcrumb *crumb =
        [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                       category:@"device.event"];
    crumb.type = @"system";
    crumb.data = batteryData;
    [SentrySDK addBreadcrumb:crumb];
}

- (NSDictionary*)getBatteryStatus
{
    // borrowed and adapted from https://github.com/apache/cordova-plugin-battery-status/blob/master/src/ios/CDVBattery.m
    UIDevice* currentDevice = [UIDevice currentDevice];
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
    }
    [batteryData setValue:[NSNumber numberWithBool:isPlugged] forKey:@"plugged"];

    return batteryData;
}

@end
