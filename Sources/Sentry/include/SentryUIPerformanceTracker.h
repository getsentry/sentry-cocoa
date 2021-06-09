#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_VIEWCONTROLLER_RENDERING_OPERATION = @"ui.rendering";

/**
 * Class responsible to track UI performance.
 * This class is intended to be used in a swizzled context.
 */
@interface SentryUIPerformanceTracker : NSObject

@property (nonatomic, readonly, class) SentryUIPerformanceTracker *shared;

/**
 * Measures viewController`s loadView method.
 * This method starts a span that will be finished when
 * viewControllerDidAppear:callBackToOrigin: is called.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * LoadView method.
 */
- (void)viewControllerLoadView:(id)controller callbackToOrigin:(Callback)callback;

/**
 * Measures viewController`s viewDidLoad method.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewDidLoad method.
 */
- (void)viewControllerViewDidLoad:(id)controller callbackToOrigin:(Callback)callback;

/**
 * Measures viewController`s viewWillAppear: method.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewWillAppear: method.
 */
- (void)viewControllerViewWillAppear:(id)controller callbackToOrigin:(Callback)callback;

/**
 * Measures viewController`s viewDidAppear: method.
 * This method also finishes the span created at
 * viewControllerLoadView:callbackToOrigin: allowing
 * the transaction to be send to Sentry when all spans are finished.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewDidAppear: method.
 */
- (void)viewControllerViewDidAppear:(id)controller callbackToOrigin:(Callback)callback;

/**
 * Measures viewController`s viewWillLayoutSubViews method.
 * This method starts a span that is only finish when
 * viewControllerViewDidLayoutSubViews:callbackToOrigin: is called.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewWillLayoutSubViews method.
 */
- (void)viewControllerViewWillLayoutSubViews:(id)controller callbackToOrigin:(Callback)callback;

/**
 * Measures viewController`s viewDidLayoutSubViews method.
 * This method also finished the span created at
 * viewControllerViewWillLayoutSubViews:callbackToOrigin:
 * that measures all work done in views between this two methods.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewDidLayoutSubViews method.
 */
- (void)viewControllerViewDidLayoutSubViews:(id)controller callbackToOrigin:(Callback)callback;

@end

NS_ASSUME_NONNULL_END
