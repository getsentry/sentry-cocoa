#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryPermissionsObserver : NSObject

@property (nonatomic) SentryPermissionStatus pushPermissionStatus;
@property (nonatomic) SentryPermissionStatus locationPermissionStatus;
@property (nonatomic) SentryPermissionStatus mediaLibraryPermissionStatus;
@property (nonatomic) SentryPermissionStatus photoLibraryPermissionStatus;

- (void)startObserving;

@end

NS_ASSUME_NONNULL_END
