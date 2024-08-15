#import <Foundation/Foundation.h>

#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryUserFeedbackWidgetConfiguration : NSObject

/**
 * Injects the Feedback widget into the application UI when the integration is added. Set to @c NO
 * if you want to call @code -[SentryUserFeedbackIntegration attachToButton:] @endcode or
 * @code -[SentryUserFeedbackIntegration createWidget] @endcode directly, or only want to show the
 * widget on certain views.
 * @note Default: @c YES
 */
@property (nonatomic, assign) BOOL autoInject;

/**
 * The label of the injected button that opens up the feedback form when clicked.
 * @note Default: @"Report a Bug"
 */
@property (nonatomic, copy) NSString *triggerLabel;

/**
 * The accessibility label of the injected button that opens up the feedback form when clicked.
 * @note Default: @c triggerLabel value
 */
@property (nonatomic, copy) NSString *triggerAccessibilityLabel;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
