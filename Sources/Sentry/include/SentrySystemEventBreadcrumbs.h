#import "SentryCurrentDateProvider.h"
#import "SentryFileManager.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>
#endif

@class SentryNSNotificationCenterWrapper;

@interface SentrySystemEventBreadcrumbs : NSObject
SENTRY_NO_INIT

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager
             andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
       andNotificationCenterWrapper:(SentryNSNotificationCenterWrapper *)notificationCenterWrapper;

- (void)start;

#if TARGET_OS_IOS
- (void)start:(UIDevice *)currentDevice;
- (void)timezoneEventTriggered;
#endif

- (void)stop;

@end
