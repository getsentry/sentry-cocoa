#import "SentryPermissionsObserver.h"
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryPermissionsObserver () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@end

@implementation SentryPermissionsObserver

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self startObserving];
    }
    return self;
}

- (void)startObserving
{
    // Set initial values
    [self checkPushPermissions];
    [self setLocationPermissionFromStatus:[CLLocationManager authorizationStatus]];

    // Listen for location permission updates
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    // We can't listen for push permission updates directly, there simply is no API for that.
    // Instead we re-check when the application comes back to the foreground.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkPushPermissions)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)checkPushPermissions
{
    if (@available(iOS 10, *)) {
        [[UNUserNotificationCenter currentNotificationCenter]
            getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                [self setPushPermissionFromStatus:settings.authorizationStatus];
            }];
    }
}

- (void)setPushPermissionFromStatus:(UNAuthorizationStatus)status
{
    switch (status) {
    case UNAuthorizationStatusNotDetermined:
        self.pushPermissionStatus = kPermissionStatusUnknown;
        break;

    case UNAuthorizationStatusDenied:
        self.pushPermissionStatus = kPermissionStatusDenied;
        break;

    case UNAuthorizationStatusAuthorized:
    case UNAuthorizationStatusProvisional:
    case UNAuthorizationStatusEphemeral:
        self.pushPermissionStatus = kPermissionStatusGranted;
        break;
    }
}

- (void)setLocationPermissionFromStatus:(CLAuthorizationStatus)status
{
    switch (status) {
    case kCLAuthorizationStatusNotDetermined:
        self.locationPermissionStatus = kPermissionStatusUnknown;
        break;

    case kCLAuthorizationStatusDenied:
    case kCLAuthorizationStatusRestricted:
        self.locationPermissionStatus = kPermissionStatusDenied;
        break;

    case kCLAuthorizationStatusAuthorizedAlways:
    case kCLAuthorizationStatusAuthorizedWhenInUse:
        self.locationPermissionStatus = kPermissionStatusGranted;
        break;
    }
}

- (void)locationManager:(CLLocationManager *)manager
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self setLocationPermissionFromStatus:status];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    CLAuthorizationStatus locationStatus = [CLLocationManager authorizationStatus];
    [self setLocationPermissionFromStatus:locationStatus];
}

@end

NS_ASSUME_NONNULL_END
