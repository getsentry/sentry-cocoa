#import "SentryPermissionsObserver.h"
#import <CoreLocation/CoreLocation.h>

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
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;

        CLAuthorizationStatus locationStatus = [CLLocationManager authorizationStatus];
        [self setLocationPermissionFromStatus:locationStatus];
    }

    return self;
}

- (void)setLocationPermissionFromStatus:(CLAuthorizationStatus)locationStatus
{
    switch (locationStatus) {
    case kCLAuthorizationStatusNotDetermined:
        self.hasLocationPermission = kPermissionStatusUnknown;
        break;

    case kCLAuthorizationStatusDenied:
    case kCLAuthorizationStatusRestricted:
        self.hasLocationPermission = kPermissionStatusDenied;
        break;

    case kCLAuthorizationStatusAuthorizedAlways:
    case kCLAuthorizationStatusAuthorizedWhenInUse:
        self.hasLocationPermission = kPermissionStatusGranted;
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
