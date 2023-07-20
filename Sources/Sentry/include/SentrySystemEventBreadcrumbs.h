#import "SentryFileManager.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryNSNotificationCenterWrapper;

@protocol SentryBreadcrumbDelegate;

@interface SentrySystemEventBreadcrumbs : NSObject
SENTRY_NO_INIT

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager
       andNotificationCenterWrapper:(SentryNSNotificationCenterWrapper *)notificationCenterWrapper;

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate;

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate
            currentDevice:(nullable UIDevice *)currentDevice;
- (void)timezoneEventTriggered;
#endif

- (void)stop;

@end

NS_ASSUME_NONNULL_END
