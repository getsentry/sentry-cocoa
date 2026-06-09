#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// API for interacting with the User Feedback feature.
@interface SentryObjCFeedbackApi : NSObject
SENTRY_NO_INIT

/**
 * Show the feedback widget button.
 * @warning This is an experimental feature and may still have bugs.
 * @deprecated The Sentry-managed User Feedback widget is deprecated and will be removed in v10.
 */
- (void)showWidget NS_EXTENSION_UNAVAILABLE("Not available in app extensions.")
    __attribute__((deprecated("The Sentry-managed User Feedback widget is deprecated and will be "
                              "removed in v10.")));

/**
 * Hide the feedback widget button.
 * @warning This is an experimental feature and may still have bugs.
 * @deprecated The Sentry-managed User Feedback widget is deprecated and will be removed in v10.
 */
- (void)hideWidget NS_EXTENSION_UNAVAILABLE("Not available in app extensions.")
    __attribute__((deprecated("The Sentry-managed User Feedback widget is deprecated and will be "
                              "removed in v10.")));

@end

NS_ASSUME_NONNULL_END

#endif
