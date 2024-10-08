#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentryOptions.h>
#else
#    import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Block used to configure the user feedback widget, form, behaviors and submission data.
 */
typedef void (^SentryUserFeedbackConfigurationBlock)(
    SentryUserFeedbackConfiguration *_Nonnull configuration);

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface SentryOptions ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;
- (BOOL)isContinuousProfilingEnabled;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

/**
 * A block that can be defined that receives a user feedback configuration object to modify.
 * @warning This is an experimental feature and may still have bugs.
 * @note This is unrelated to @c SentrySDK.captureUserFeedback which is a method you can call to
 * directly submit user feedback that you've already gathered via your own UI. See
 * https://docs.sentry.io/platforms/apple/user-feedback/#user-feedback-api and (TODO: add link to
 * new docs) for more information on each approach.
 */
@property (nonatomic, copy, nullable) SentryUserFeedbackConfigurationBlock configureUserFeedback;

SENTRY_EXTERN BOOL sentry_isValidSampleRate(NSNumber *sampleRate);

@end

NS_ASSUME_NONNULL_END
