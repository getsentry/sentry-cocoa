#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kPermissionStatusUnknown,
    kPermissionStatusGranted,
    kPermissionStatusDenied
} SentryPermissionStatus;

@interface SentryPermissionsObserver : NSObject

@property (nonatomic) SentryPermissionStatus pushPermissionStatus;
@property (nonatomic) SentryPermissionStatus locationPermissionStatus;

@end

NS_ASSUME_NONNULL_END
