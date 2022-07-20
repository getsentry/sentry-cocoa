#import "SentryPermissionsObserver.h"
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>

#if SENTRY_HAS_UIKIT
#    import <Photos/Photos.h>
#    import <UIKit/UIKit.h>
#endif

#if TARGET_OS_IOS
#    import <MediaPlayer/MediaPlayer.h>
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
#if TARGET_OS_IOS
    if (@available(iOS 9.3, *)) {
        [self setMediaLibraryPermissionFromStatus:MPMediaLibrary.authorizationStatus];
    }
#endif

#if SENTRY_HAS_UIKIT
    if (@available(iOS 9, tvOS 10, *)) {
        [self setPhotoLibraryPermissionFromStatus:PHPhotoLibrary.authorizationStatus];
    }

    if (@available(iOS 10, tvOS 10, *)) {
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

#if TARGET_OS_IOS
- (void)setMediaLibraryPermissionFromStatus:(MPMediaLibraryAuthorizationStatus)status
    API_AVAILABLE(ios(9.3))
{
    switch (status) {
    case MPMediaLibraryAuthorizationStatusNotDetermined:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusUnknown;
        break;
    case MPMediaLibraryAuthorizationStatusDenied:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusDenied;
        break;
    case MPMediaLibraryAuthorizationStatusRestricted: // The app may access some of the content in
                                                      // the user's media library.
    case MPMediaLibraryAuthorizationStatusAuthorized:
        self.mediaLibraryPermissionStatus = kSentryPermissionStatusGranted;
        break;
    }
}
#endif

#if SENTRY_HAS_UIKIT
- (void)setPhotoLibraryPermissionFromStatus:(PHAuthorizationStatus)status
    API_AVAILABLE(ios(9), tvos(10))
{
    switch (status) {
    case PHAuthorizationStatusNotDetermined:
        self.photoLibraryPermissionStatus = kSentryPermissionStatusUnknown;
        break;
    case PHAuthorizationStatusDenied:
    case PHAuthorizationStatusRestricted: // The app isn’t authorized to access the photo library,
                                          // and the user can’t grant such permission.
        self.photoLibraryPermissionStatus = kSentryPermissionStatusDenied;
        break;
    case PHAuthorizationStatusLimited:
    case PHAuthorizationStatusAuthorized:
        self.photoLibraryPermissionStatus = kSentryPermissionStatusGranted;
        break;
    }
}

- (void)setPushPermissionFromStatus:(UNAuthorizationStatus)status API_AVAILABLE(ios(10), tvos(10))
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
