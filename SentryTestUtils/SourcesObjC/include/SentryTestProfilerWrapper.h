// SwiftPM replacement for the profiler portion of SentryTests-Bridging-Header.h.
// Xcode project tests continue to use their bridging header directly.
#import "SentryProfilingConditionals.h"

#if SWIFT_PACKAGE && !SDK_V10 && SENTRY_TARGET_PROFILING_SUPPORTED
@import _SentryPrivate;
#    import "SentryContinuousProfiler+Test.h"
#    import "SentryFileManager+Test.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfilerDefines.h"
#    import "SentryProfilerSerialization+Test.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySDKInternal+Tests.h"
#    import "SentryTraceProfiler+Test.h"

NS_ASSUME_NONNULL_BEGIN

// SentryOptions is a Swift type. Its forward declaration in _SentryPrivate cannot be imported
// back into Swift across the package's module boundary. Keep the erased bridge test-only.
FOUNDATION_EXPORT void sentry_test_sdkInitProfilerTasks(NSObject *options, SentryHubInternal *hub)
    NS_SWIFT_NAME(sentry_sdkInitProfilerTasks(_:_:));
FOUNDATION_EXPORT void sentry_test_configureContinuousProfiling(NSObject *options)
    NS_SWIFT_NAME(sentry_configureContinuousProfiling(_:));

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
