#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
@import _SentryPrivate;

// These original headers are directly importable by both Xcode and SwiftPM tests,
// including V10's main-suite profiling tests.
#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler+Test.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfilerSerialization+Test.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentryTraceProfiler+Test.h"
#endif

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryFileManager+Test.h"
#    import "SentryLaunchProfiling+Tests.h"
#    import "SentryProfilerSerialization.h"
#    import "SentrySDKInternal+Tests.h"

NS_ASSUME_NONNULL_BEGIN

// SentryOptions is a Swift type. Its forward declaration in _SentryPrivate cannot be imported
// back into Swift across the package's module boundary. Keep the erased bridge test-only.
FOUNDATION_EXPORT void sentry_test_sdkInitProfilerTasks(NSObject *options, SentryHubInternal *hub)
    NS_SWIFT_NAME(sentry_sdkInitProfilerTasks(_:_:));
FOUNDATION_EXPORT void sentry_test_configureContinuousProfiling(NSObject *options)
    NS_SWIFT_NAME(sentry_configureContinuousProfiling(_:));
FOUNDATION_EXPORT void sentry_test_configureLaunchProfilingForNextLaunch(NSObject *options)
    NS_SWIFT_NAME(sentry_configureLaunchProfilingForNextLaunch(_:));
FOUNDATION_EXPORT BOOL sentry_test_willProfileNextLaunch(NSObject *options)
    NS_SWIFT_NAME(sentry_willProfileNextLaunch(_:));

NS_ASSUME_NONNULL_END
#endif

#if SENTRY_HAS_UIKIT
NS_ASSUME_NONNULL_BEGIN

// Shared by main-suite and profiler tests in both SDK versions and build systems.
// The implementation restores the Swift-defined protocol behind the Clang module boundary.
@interface TestDelayedWrapper : SentryDelayedFramesTracker
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(id)dateProvider; // OK: Swift protocol bridge.
@end

NS_ASSUME_NONNULL_END
#endif
