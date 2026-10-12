#import "SentryProfilingConditionals.h"

// These original headers are directly importable by both Xcode and SwiftPM tests,
// including V10's main-suite profiling tests. Only the existing adapters below are V9-only.
#if SENTRY_TARGET_PROFILING_SUPPORTED
@import _SentryPrivate;
#    import "SentryContinuousProfiler+Test.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfilerSerialization+Test.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentryTraceProfiler+Test.h"
#endif

#if SWIFT_PACKAGE && !SDK_V10 && SENTRY_TARGET_PROFILING_SUPPORTED
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

#    if SENTRY_HAS_UIKIT
// Redeclare the initializer without its Swift-defined protocol parameter, which SwiftPM's
// Clang importer cannot resolve through the superclass's forward declaration.
@interface TestDelayedWrapper : SentryDelayedFramesTracker
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(id)dateProvider; // OK: Swift protocol bridge.
@end
#    endif

NS_ASSUME_NONNULL_END
#endif
