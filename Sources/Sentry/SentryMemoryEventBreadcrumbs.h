#import "SentryFileManager.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryBreadcrumbDelegate;

@interface SentryMemoryEventBreadcrumbs : NSObject

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate;
- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
