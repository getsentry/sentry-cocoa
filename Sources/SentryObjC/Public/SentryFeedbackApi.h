#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#import "SentryObjCDefines.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * API for interacting with the User Feedback feature.
 *
 * Access this through @c +[SentryObjcSDK feedback].
 */
@interface SentryFeedbackAPI : NSObject

/**
 * Show the feedback widget button.
 *
 * @warning This is an experimental feature and may still have bugs.
 * @see @c SentryOptions.configureUserFeedback to configure the widget.
 */
- (void)showWidget;

/**
 * Hide the feedback widget button.
 *
 * @warning This is an experimental feature and may still have bugs.
 * @see @c SentryOptions.configureUserFeedback to configure the widget.
 */
- (void)hideWidget;

@end

NS_ASSUME_NONNULL_END

#endif
