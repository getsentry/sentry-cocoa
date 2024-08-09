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
 * @note Default: @c UIWindowLevelAlert
 */
@property (nonatomic, assign) UIWindowLevel windowLevel;

/**
 * The inset value for positioning the widget.
 * @note Default: @"auto 0 0 auto"
 * TODO: convert this from CSS-centric to UIKit-centric
 */
@property (nonatomic, copy) NSString *inset;

/**
 * The margin from the edge of the screen that the widget should be positioned.
 * @note Default: @"16px"
 * TODO: convert this from CSS-centric to UIKit-centric
 */
@property (nonatomic, copy) NSString *pageMargin;

/**
 * Foreground (text) color.
 * @note Defaults light mode: @"#2b2233"; dark mode: @"#ebe6ef"
 * TODO: convert to RGB
 */
@property (nonatomic, strong) UIColor *foreground;

/**
 * Background color of the widget (injected button and form).
 * @note Default light mode: @"#ffffff"; dark mode: @"#29232f"
 * TODO: convert to RGB
 */
@property (nonatomic, strong) UIColor *background;

/**
 * Foreground color for the submit button.
 * @note Default: @"#ffffff" for both dark and light modes
 * TODO: convert to RGB
 */
@property (nonatomic, strong) UIColor *accentForeground;

/**
 * Background color for the submit button in light and dark modes.
 * @note Default: @"rgba(88, 74, 192, 1)" for both light and dark modes
 */
@property (nonatomic, strong) UIColor *accentBackground;

/**
 * Color used for success-related components (such as text color when feedback is submitted
 * successfully).
 * @note Default light mode: @"#268d75"; dark mode: @"#2da98c"
 * TODO: convert to RGB
 */
@property (nonatomic, strong) UIColor *successColor;

/**
 * Color used for error-related components (such as text color when there's an error submitting
 * feedback).
 * @note Default light mode: @"#df3338"; dark mode: @"#f55459"
 * TODO: convert to RGB
 */
@property (nonatomic, strong) UIColor *errorColor;

/**
 * Outline for form inputs when focused.
 * @note Default: @"1px auto var(--accent-background)"
 * TODO: convert this from CSS-centric to UIKit-centric
 */
@property (nonatomic, copy) UIColor *outlineColor;

/**
 * Outline for form inputs when focused.
 * @note Default: @"1px auto var(--accent-background)"
 * TODO: convert this from CSS-centric to UIKit-centric
 */
@property (nonatomic, assign) CGFloat outlineThickness;

/**
 * Outline for form inputs when focused.
 * @note Default: @"1px auto var(--accent-background)"
 * TODO: convert this from CSS-centric to UIKit-centric
 */
@property (nonatomic, assign) CGFloat outlineCornerRadius;

@end

#endif // SENTRY_HAS_UIKIT
