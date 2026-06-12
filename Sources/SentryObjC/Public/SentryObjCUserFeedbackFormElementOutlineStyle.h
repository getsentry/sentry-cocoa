#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

@class UIColor;

NS_ASSUME_NONNULL_BEGIN

/// Options for styling the outline of input elements and buttons in the User Feedback form.
@interface SentryObjCUserFeedbackFormElementOutlineStyle : NSObject

/**
 * Outline color for form inputs.
 * @note Default value is a light gray color.
 */
@property (nonatomic, strong) UIColor *color;

/**
 * Outline corner radius for form input elements.
 * @note Default value is @c 5.
 */
@property (nonatomic) CGFloat cornerRadius;

/**
 * The thickness of the outline.
 * @note Default value is @c 0.5.
 */
@property (nonatomic) CGFloat outlineWidth;

/// Initializes outline style with default values.
- (instancetype)init;

/**
 * Initializes outline style with the specified parameters.
 * @param color The outline color.
 * @param cornerRadius The outline corner radius.
 * @param outlineWidth The outline width.
 */
- (instancetype)initWithColor:(UIColor *)color
                 cornerRadius:(CGFloat)cornerRadius
                 outlineWidth:(CGFloat)outlineWidth;

@end

NS_ASSUME_NONNULL_END

#endif
