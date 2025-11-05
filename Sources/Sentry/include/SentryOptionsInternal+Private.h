#if __has_include(<Sentry/SentryOptionsInternal.h>)
#    import <Sentry/SentryOptionsInternal.h>
#else
#    import "SentryOptionsInternal.h"
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface SentryOptionsInternal ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;

/**
 * UI Profiling options set on SDK start.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
@property (nonatomic, nullable, strong) SentryProfileOptions *profiling;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

SENTRY_EXTERN BOOL sentry_isValidSampleRate(NSNumber *sampleRate);

@end

NS_ASSUME_NONNULL_END
