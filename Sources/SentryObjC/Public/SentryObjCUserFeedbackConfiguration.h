#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

@class UIButton;
@class SentryObjCUserFeedbackFormConfiguration;
@class SentryObjCUserFeedbackThemeConfiguration;
NS_ASSUME_NONNULL_BEGIN

/// Settings for how the User Feedback form is presented, customized, and submitted.
@interface SentryObjCUserFeedbackConfiguration : NSObject

/**
 * Whether or not to show animations, like for presenting and dismissing the form.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL animations;

/**
 * Use a shake gesture to display the form.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL useShakeGesture;

/**
 * Any time a user takes a screenshot, bring up the form with the screenshot attached.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL showFormForScreenshots;

/**
 * Install a hook for the specified button to show the form when it is pressed.
 * @note Default value is @c nil.
 * @deprecated The custom User Feedback button configuration is deprecated and will be removed in
 * v10. Add your own button action and call @c [[SentryObjCSDK feedback] show] instead.
 */
@property (nonatomic, strong, nullable) UIButton *customButton
    __attribute__((deprecated("The custom User Feedback button configuration is deprecated and "
                              "will be removed in v10. Add your own button action and call "
                              "[[SentryObjCSDK feedback] show] instead.")));

/**
 * Configuration settings specific to the managed UI form to gather user input.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) void (^configureForm)
    (SentryObjCUserFeedbackFormConfiguration *configuration);

/**
 * Tags to set on the feedback event.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *tags;

/**
 * Called when the managed feedback form is opened.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) void (^onFormOpen)(void);

/**
 * Called when the managed feedback form is closed.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) void (^onFormClose)(void);

/**
 * Called when feedback is successfully submitted via the managed feedback form.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) void (^onSubmitSuccess)(NSDictionary<NSString *, id> *info);

/**
 * Called when there is an error submitting feedback via the managed feedback form.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) void (^onSubmitError)(NSError *error);

/**
 * Builder for default/light theme overrides.
 * @note Default value is @c nil.
 */
@property (nonatomic, copy, nullable) void (^configureTheme)
    (SentryObjCUserFeedbackThemeConfiguration *configuration);

/// Initializes user feedback configuration with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

#endif
