#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kPermissionStatusUnknown,
    kPermissionStatusGranted,
    kPermissionStatusDenied
} SentryPermissionStatus;

@interface SentryPermissionsObserver : NSObject

@property (nonatomic) SentryPermissionStatus hasPushPermission;
@property (nonatomic) SentryPermissionStatus hasLocationPermission;

@end

NS_ASSUME_NONNULL_END
