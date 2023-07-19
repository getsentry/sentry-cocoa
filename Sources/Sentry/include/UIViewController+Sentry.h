#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

// !!!: forces UIKit linkage; has to be moved to separate target
//@interface
// UIViewController (Sentry)
//
///**
// * An array of view controllers that are descendants, meaning children, grandchildren, ... , of
// the
// * current view controller.
// */
//@property (nonatomic, readonly, strong)
//    NSArray<UIViewController *> *sentry_descendantViewControllers;
//
//@end

NS_ASSUME_NONNULL_END

#endif
