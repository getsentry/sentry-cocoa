#import "SentryPermissionsObserver.h"
#import <CoreLocation/CoreLocation.h>
#import <MediaPlayer/MediaPlayer.h>
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
    [self refreshPermissions];
    [self setLocationPermissionFromStatus:[CLLocationManager authorizationStatus]];

    // Listen for location permission updates
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

#if SENTRY_HAS_UIKIT
    // For most permissions there is no API for to be notified of changes (delegate, completion
    // handler). Instead we refresh the values when the application comes back to the foreground.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshPermissions)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#endif
}

- (void)refreshPermissions
{
    [self setMediaLibraryPermissionFromStatus:MPMediaLibrary.authorizationStatus];

#if SENTRY_HAS_UIKIT
    if (@available(iOS 10, *)) {
        // We can not access UNUserNotificationCenter from tests, or it'll crash
        // with error `bundleProxyForCurrentProcess is nil`.
        if (NSBundle.mainBundle.bundleIdentifier != nil
            && ![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.dt.xctest.tool"]) {
            [[UNUserNotificationCenter currentNotificationCenter]
                getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                    [self setPushPermissionFromStatus:settings.authorizationStatus];
                }];
        }
    }
#endif
}

- (void)setMediaLibraryPermissionFromStatus:(MPMediaLibraryAuthorizationStatus)status
{
    switch (status) {
    case MPMediaLibraryAuthorizationStatusNotDetermined:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusUnknown;
        break;
    case MPMediaLibraryAuthorizationStatusDenied:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusDenied;
        break;
    case MPMediaLibraryAuthorizationStatusRestricted:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusGranted;
        break;
    case MPMediaLibraryAuthorizationStatusAuthorized:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusGranted;
        break;
    }
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
        self.pushPermissionStatus = kSentryPermissionStatusGranted;
        break;

#    if TARGET_OS_IOS
    case UNAuthorizationStatusEphemeral:
        self.pushPermissionStatus = kSentryPermissionStatusGranted;
        break;
#    endif
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

#if !TARGET_OS_OSX
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
