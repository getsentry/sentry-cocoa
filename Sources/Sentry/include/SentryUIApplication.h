//#if SENTRY_HAS_UIKIT
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A helper tool to retrieve informations from the application instance.
 */
@interface SentryUIApplication : NSObject

/**
 * Application shared UIApplication instance.
 */
@property (class, nonatomic, readonly, nullable) UIApplication *sharedApplication;

/**
 * All application open windows.
 */
@property (class, nonatomic, readonly, nullable) NSArray<UIWindow *> *windows;

@end

NS_ASSUME_NONNULL_END
//#endif
