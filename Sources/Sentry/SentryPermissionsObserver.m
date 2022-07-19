#import "SentryPermissionsObserver.h"
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

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

#if SENTRY_HAS_UIKIT
    // We can't listen for push permission updates directly, there simply is no API for that.
    // Instead we re-check when the application comes back to the foreground.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkPushPermissions)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#endif
}

- (void)checkPushPermissions
{
#if SENTRY_HAS_UIKIT
    if (@available(iOS 10, *)) {
        [[UNUserNotificationCenter currentNotificationCenter]
            getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                [self setPushPermissionFromStatus:settings.authorizationStatus];
            }];
    }
#endif
}

#if SENTRY_HAS_UIKIT
- (void)setPushPermissionFromStatus:(UNAuthorizationStatus)status
{
    switch (status) {
    case UNAuthorizationStatusNotDetermined:
        self.pushPermissionStatus = kSentryPermissionStatusUnknown;
        break;

    case UNAuthorizationStatusDenied:
        self.pushPermissionStatus = kSentryPermissionStatusDenied;
        break;

    case UNAuthorizationStatusAuthorized:
    case UNAuthorizationStatusProvisional:
    case UNAuthorizationStatusEphemeral:
        self.pushPermissionStatus = kSentryPermissionStatusGranted;
        break;
    }
}
#endif

- (void)setLocationPermissionFromStatus:(CLAuthorizationStatus)status
{
    switch (status) {
    case kCLAuthorizationStatusNotDetermined:
        self.locationPermissionStatus = kSentryPermissionStatusUnknown;
        break;

    case kCLAuthorizationStatusDenied:
    case kCLAuthorizationStatusRestricted:
        self.locationPermissionStatus = kSentryPermissionStatusDenied;
        break;

    case kCLAuthorizationStatusAuthorizedAlways:
        self.locationPermissionStatus = kSentryPermissionStatusGranted;
        break;

#if SENTRY_HAS_UIKIT
    case kCLAuthorizationStatusAuthorizedWhenInUse:
        self.locationPermissionStatus = kSentryPermissionStatusGranted;
        break;
#endif
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
