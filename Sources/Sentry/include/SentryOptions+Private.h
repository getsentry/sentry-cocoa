#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentryOptions.h>
#else
#    import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Block used to configure the user feedback widget, form, behaviors and submission data.
 */
API_AVAILABLE(ios(13.0))
typedef void (^SentryUserFeedbackConfigurationBlock)(
    SentryUserFeedbackConfiguration *_Nonnull configuration);

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface SentryOptions ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;
- (BOOL)isContinuousProfilingEnabled;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
/**
 * A block that can be defined that receives a user feedback configuration object to modify.
 * @warning This is an experimental feature and may still have bugs.
 * @note This is unrelated to @c SentrySDK.captureUserFeedback which is a method you can call to
 * directly submit user feedback that you've already gathered via your own UI. See
 * https://docs.sentry.io/platforms/apple/user-feedback/#user-feedback-api and (TODO: add link to
 * new docs) for more information on each approach.
 */
@property (nonatomic, copy, nullable)
    SentryUserFeedbackConfigurationBlock configureUserFeedback API_AVAILABLE(ios(13.0));
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

@property (nonatomic, readonly, class) NSArray<Class> *defaultIntegrationClasses;

@property (nonatomic, strong, nullable)
    SentryUserFeedbackConfiguration *userFeedbackConfiguration API_AVAILABLE(ios(13.0));

SENTRY_EXTERN BOOL sentry_isValidSampleRate(NSNumber *sampleRate);

@end

NS_ASSUME_NONNULL_END
