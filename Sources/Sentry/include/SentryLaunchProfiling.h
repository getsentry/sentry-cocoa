#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryHub;
@class SentryId;
@class SentryOptions;
@class SentryTracerConfiguration;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN BOOL isTracingAppLaunch;

/** Try to start a profiled trace for this app launch, if the configuration allows. */
SENTRY_EXTERN void startLaunchProfile(void);

/**
 * Stop any profiled trace that may be in flight from the start of the app launch.
 * @param hub Pass a @c SentryHub instance if this profile needs to be attached to a dedicated
 * transaction, like if we're profiling a SwiftUI app launch, or the SDK is not configured to
 * automatically track UIViewController loads. Otherwise, the profile data will be attached to the
 * automatically created spans, so pass @c nil here so that the dedicated transaction is discarded.
 */
void stopLaunchProfile(SentryHub *_Nullable hub);

/**
 * Write a file to disk containing sample rates for profiles and traces. The presence of this file
 * will let the profiler know to start on the app launch, and the sample rates contained will help
 * thread sampling decisions through to SentryHub later when it needs to start a transaction for the
 * profile to be attached to.
 */
void configureLaunchProfiling(SentryOptions *options);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
