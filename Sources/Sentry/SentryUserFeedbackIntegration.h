#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryUserFeedbackWidgetConfiguration;

@interface SentryUserFeedbackIntegration : NSObject

- (instancetype)initWithConfiguration:(SentryUserFeedbackWidgetConfiguration *)configuration;

/**
 * Attaches the feedback widget to a specified UIButton. The button will trigger the feedback form.
 * @param button The UIButton to attach the widget to.
 */
- (void)attachToButton:(UIButton *)button;

/**
 * Creates and renders the feedback widget on the screen. If autoInject is NO, this must be called
 * explicitly.
 */
- (void)createWidget;

/**
 * Removes the feedback widget from the view hierarchy. Useful for cleanup when the widget is no
 * longer needed.
 */
- (void)removeWidget;

/**
 * Captures feedback using custom UI. This method allows you to submit feedback data directly.
 * @param message The feedback message (required).
 * @param name The name of the user (optional).
 * @param email The email of the user (optional).
 * @param hints Additional hints or metadata for the feedback submission (optional).
 */
- (void)captureFeedback:(NSString *)message
                   name:(nullable NSString *)name
                  email:(nullable NSString *)email
                  hints:(nullable NSDictionary *)hints;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
