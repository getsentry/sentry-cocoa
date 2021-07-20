#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@interface UIViewController (Sentry)

/**
 * An array of view controllers that are descendants, meaning children, grandchildren, ... , of the
 * current view controller.
 */
@property (nonatomic, readonly, strong) NSArray<UIViewController *> *descendantViewControllers;

@end

#endif

NS_ASSUME_NONNULL_END
