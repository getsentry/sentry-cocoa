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
 * If UI profiling mode ("continuous v2") is enabled.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
- (BOOL)isContinuousProfilingEnabled;

/**
 * Whether or not the SDK was configured with a profile mode that automatically starts and tracks
 * profiles with traces.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
- (BOOL)isProfilingCorrelatedToTraces;

/**
 * UI Profiling options set on SDK start.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
@property (nonatomic, nullable, strong) SentryProfileOptions *profiling;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

SENTRY_EXTERN BOOL sentry_isValidSampleRate(NSNumber *sampleRate);

#if SENTRY_HAS_UIKIT
- (BOOL)isAppHangTrackingDisabled;
#endif // SENTRY_HAS_UIKIT
@end

NS_ASSUME_NONNULL_END
