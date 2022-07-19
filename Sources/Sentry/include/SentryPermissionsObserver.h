#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryPermissionsObserver : NSObject

@property (nonatomic) SentryPermissionStatus pushPermissionStatus;
@property (nonatomic) SentryPermissionStatus locationPermissionStatus;

- (void)startObserving;

@end

NS_ASSUME_NONNULL_END
