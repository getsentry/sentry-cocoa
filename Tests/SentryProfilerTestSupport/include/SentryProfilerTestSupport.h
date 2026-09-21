// SwiftPM replacement for the profiler portion of SentryTests-Bridging-Header.h.
// Keep these declarations in a test-only module, not in the SDK's private/public API.
#import "SentryProfilingConditionals.h"

#if !SDK_V10 && SENTRY_TARGET_PROFILING_SUPPORTED
@import _SentryPrivate;
#    import "../../SentryTests/SentrySDKInternal+Tests.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfilerDefines.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilerTestHelpers.h"
@import SentryTestUtilsObjCpp;
#    import "../../../SentryTestUtils/Headers/SentryFileManager+Test.h"
#    import "../../../SentryTestUtils/Headers/SentryLaunchProfiling+Tests.h"
#    import "../../../Sources/Sentry/Profiling/SentryProfilerSerialization+Test.h"
#    import "../../SentryTests/SentryContinuousProfiler+Test.h"
#    import "../../SentryTests/SentryTraceProfiler+Test.h"

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
