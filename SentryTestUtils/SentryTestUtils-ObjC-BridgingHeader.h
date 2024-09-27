#import "SentryDefines.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#    define SENTRY_UIKIT_AVAILABLE 1
#else
#    define SENTRY_UIKIT_AVAILABLE 0
#endif

#if SENTRY_HAS_UIKIT
#    import "SentryAppStartTracker.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryFramesTracker+TestInit.h"
#    import "SentryUIDeviceWrapper.h"
#    import "SentryUIViewControllerPerformanceTracker.h"
#endif // SENTRY_HAS_UIKIT

#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler+Test.h"
#    import "SentryContinuousProfiler.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryProfiler+Private.h"
#    import "SentryTraceProfiler+Test.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#import "PrivateSentrySDKOnly.h"
#import "SentryAppStartMeasurement.h"
#import "SentryAppState.h"
#import "SentryClient+Private.h"
#import "SentryClient+TestInit.h"
#import "SentryCrash+Test.h"
#import "SentryCrashCachedData.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryCrashMonitor_MachException.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchFactory.h"
#import "SentryDispatchSourceWrapper.h"
#import "SentryEnvelope.h"
#import "SentryFileManager+Test.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryHub+Private.h"
#import "SentryHub+Test.h"
#import "SentryLog.h"
#import "SentryNSNotificationCenterWrapper.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryNSTimerFactory.h"
#import "SentryNetworkTracker.h"
#import "SentryPerformanceTracker+Testing.h"
#import "SentryReachability.h"
#import "SentrySDK+Private.h"
#import "SentrySDK+Tests.h"
#import "SentryScopeSyncC.h"
#import "SentrySwizzleWrapper.h"
#import "SentrySystemWrapper.h"
#import "SentryThreadInspector.h"
#import "SentryTraceContext.h"
#import "SentryTracer+Test.h"
#import "SentryTransaction.h"
#import "SentryTransport.h"
#import "SentryTransportAdapter.h"
