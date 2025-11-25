#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Needed to access SentryFeedbackIntegration until that class is written in Swift
@interface SentryFeedbackAPIHelper : NSObject

+ (void)showWidget NS_EXTENSION_UNAVAILABLE(
    "Sentry User Feedback UI cannot be used from app extensions.");

+ (void)hideWidget NS_EXTENSION_UNAVAILABLE(
    "Sentry User Feedback UI cannot be used from app extensions.");

+ (void)showForm NS_EXTENSION_UNAVAILABLE(
    "Sentry User Feedback UI cannot be used from app extensions.");

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
