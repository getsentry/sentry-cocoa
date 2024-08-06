#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryUserFeedbackConfiguration : NSObject

/**
 * Enable a shake gesture recognizer to trigger display of the user feedback modal.
 */
@property (assign, nonatomic) BOOL enableShakeGesture;

/**
 * Enable a floating button to trigger display of the user feedback modal, starting at the provided
 * @c CGRect.
 * @note Default value is @c CGRectZero , which indicates that no floating button should be used.
 */
@property (assign, nonatomic) CGRect floatingButtonInitialCoordinates;

/**
 * The primary color to use for the main design elements of the modal, such as titles or calls to
 * action to complete the worlkflow.
 */
@property (strong, nonatomic) UIColor *primaryColor;

/**
 * The secondary color to use for the secondary design elements of the modal, such as supplemental
 * explanatory text.
 */
@property (strong, nonatomic) UIColor *secondaryColor;

/**
 * The tertiary color to use for other design elements of the modal, such as cancel buttons.
 */
@property (strong, nonatomic) UIColor *tertiaryColor;

/**
 * The font family to use for labels and text inputs in the modal dialog.
 */
@property (copy, nonatomic) NSString *fontFamily;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
