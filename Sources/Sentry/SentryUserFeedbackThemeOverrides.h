#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

/**
 * Configuration class for overriding theming components for the User Feedback Widget.
 */
@interface SentryUserFeedbackThemeOverrides : NSObject

/**
 * The default font to use.
 * @note Defaults to the current system default.
 */
@property (nonatomic, strong) UIFont *font;

/**
 * The window level of the widget.
 * @note Default: @code UIWindowLevelNormal + 1 @endcode
 */
@property (nonatomic, assign) UIWindowLevel widgetWindowLevel;

/**
 * The location for positioning the widget.
 * @note Default: @code UIDirectionalRectEdgeBottom | UIDirectionalRectEdgeTrailing @endcode
 */
@property (nonatomic, assign)
    UIDirectionalRectEdge widgetDirectionalLocation API_AVAILABLE(ios(13.0));

/**
 * The location for positioning the widget.
 * @note Default: @code UIRectEdgeBottom | UIRectEdgeRight @endcode
 * @note Prefer to use @c widgetDirectionalLocation on platform versions that support
 * @c UIDirectionalRectEdge .
 */
@property (nonatomic, assign) UIRectEdge widgetLocation;

/**
 * The distance to use from the widget button to the superview's @c layoutMarginsGuide .
 * @note Default: @c UIOffsetZero .
 */
@property (nonatomic, assign) UIOffset widgetOffset;

/**
 * Foreground (text) color.
 * @note Defaults light mode: rgb(43, 34, 51); dark mode: rgb(235, 230, 239)
 */
@property (nonatomic, strong) UIColor *foreground;

/**
 * Background color of the widget (injected button and form).
 * @note Default light mode: rgb(255, 255, 255); dark mode: rgb(41, 35, 47)
 */
@property (nonatomic, strong) UIColor *background;

/**
 * Foreground color for the submit button.
 * @note Default: rgb(255, 255, 255) for both dark and light modes
 */
@property (nonatomic, strong) UIColor *accentForeground;

/**
 * Background color for the submit button in light and dark modes.
 * @note Default: rgb(88, 74, 192) for both light and dark modes
 */
@property (nonatomic, strong) UIColor *accentBackground;

/**
 * Color used for success-related components (such as text color when feedback is submitted
 * successfully).
 * @note Default light mode: rgb(38, 141, 117); dark mode: rgb(45, 169, 140)
 */
@property (nonatomic, strong) UIColor *successColor;

/**
 * Color used for error-related components (such as text color when there's an error submitting
 * feedback).
 * @note Default light mode: rgb(223, 51, 56); dark mode: rgb(245, 84, 89)
 */
@property (nonatomic, strong) UIColor *errorColor;

/**
 * Normal outline color for form inputs.
 * @note Default: @c nil (system default)
 */
@property (nonatomic, strong) UIColor *outlineColor;

/**
 * Outline color for form inputs when focused.
 * @note Default: @c nil (system default)
 */
@property (nonatomic, strong) UIColor *outlineColorFocussed;

/**
 * Normal outline thickness for form inputs.
 * @note Default: @c nil (system default)
 */
@property (nonatomic, strong) NSNumber *outlineThickness;

/**
 * Outline thickness for form inputs when focused.
 * @note Default: @c nil (system default)
 */
@property (nonatomic, strong) NSNumber *outlineThicknessFocussed;

/**
 * Outline corner radius for form input elements.
 * @note Default: @c nil (system default)
 */
@property (nonatomic, strong) NSNumber *cornerRadius;

@end

#endif // SENTRY_HAS_UIKIT
