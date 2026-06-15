#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

@class UIColor;
@class SentryObjCUserFeedbackFormElementOutlineStyle;

NS_ASSUME_NONNULL_BEGIN

/// Settings for overriding theming components for the User Feedback widget and form.
@interface SentryObjCUserFeedbackThemeConfiguration : NSObject

/**
 * The font family to use for form text elements.
 * @note Defaults to the system default if this property is @c nil.
 */
@property (nonatomic, copy, nullable) NSString *fontFamily;

/// Foreground text color of the widget and form.
@property (nonatomic, strong) UIColor *foreground;

/// Background color of the widget and form.
@property (nonatomic, strong) UIColor *background;

/// Foreground color for the form submit button.
@property (nonatomic, strong) UIColor *submitForeground;

/// Background color for the form submit button.
@property (nonatomic, strong) UIColor *submitBackground;

/// Foreground color for the cancel and screenshot buttons.
@property (nonatomic, strong) UIColor *buttonForeground;

/// Background color for the form cancel and screenshot buttons.
@property (nonatomic, strong) UIColor *buttonBackground;

/// Color used for error-related components.
@property (nonatomic, strong) UIColor *errorColor;

/// Options for styling the outline of input elements and buttons in the feedback form.
@property (nonatomic, strong) SentryObjCUserFeedbackFormElementOutlineStyle *outlineStyle;

/// Background color to use for text inputs in the feedback form.
@property (nonatomic, strong) UIColor *inputBackground;

/// Foreground color to use for text inputs in the feedback form.
@property (nonatomic, strong) UIColor *inputForeground;

/// Initializes theme configuration with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

#endif
