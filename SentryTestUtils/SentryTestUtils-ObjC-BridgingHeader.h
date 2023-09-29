#import "SentryDefines.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#    define SENTRY_UIKIT_AVAILABLE 1
#else
#    define SENTRY_UIKIT_AVAILABLE 0
#endif

#if UIKIT_LINKED
#    import "SentryAppStartTracker.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryFramesTracker+TestInit.h"
#    import "SentryUIDeviceWrapper.h"
#    import "SentryUIViewControllerPerformanceTracker.h"
#endif // UIKIT_LINKED

#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryProfiler+Test.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#import "PrivateSentrySDKOnly.h"
#import "SentryAppState.h"
#import "SentryClient+Private.h"
#import "SentryClient+TestInit.h"
#import "SentryCrashWrapper.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchFactory.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDispatchSourceWrapper.h"
#import "SentryEnvelope.h"
#import "SentryFileManager.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryNSTimerFactory.h"
#import "SentryNetworkTracker.h"
#import "SentryPerformanceTracker+Testing.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentrySDK+Tests.h"
#import "SentrySession.h"
#import "SentrySwizzleWrapper.h"
#import "SentrySystemWrapper.h"
#import "SentryThreadInspector.h"
#import "SentryTraceContext.h"
#import "SentryTracer+Test.h"
#import "SentryTransport.h"
#import "SentryTransportAdapter.h"
