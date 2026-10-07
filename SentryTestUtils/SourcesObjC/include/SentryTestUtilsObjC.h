// Module entry point shared by SwiftPM and Xcode. Import headers needed by Swift test consumers
// here; implementation-only headers stay beside their .m files, outside include/.
//
// Implementation-only SDK dependencies use same-named forwarding headers in SourcesObjC/.
// Keep those out of this entry point. SwiftPM's target-local
// .headerSearchPath(".") resolves nested imports such as SentryLogC.h -> SentryAsyncSafeLog.h
// without adding whole SDK source directories to the search path. A private aggregate header
// cannot replace the forwarding headers because SDK imports reference their exact filenames.

// Share original, Swift-importable SDK declarations between Xcode and SwiftPM tests
// instead of relying on a target-wide bridging header or extending _SentryPrivate.
// Keep generated Swift interfaces out of this module to avoid import cycles.
// Load the owning module before categories so Swift retains the base types' module identity.
@import _SentryPrivate;
#import "../../../Sources/Sentry/include/NSMutableDictionary+Sentry.h"
#import "../../../Sources/Sentry/include/SentryFormatter.h"
#import "../../../Sources/Sentry/include/SentryGeo+Private.h"
#import "../../../Sources/Sentry/include/SentryHttpStatusCodeRange+Private.h"
#import "../../../Sources/Sentry/include/SentryInternalNotificationNames.h"
#import "../../../Sources/Sentry/include/SentrySampleDecision+Private.h"
#import "../../../Sources/Sentry/include/SentryTracer+Private.h"
#import "../../../Sources/Sentry/include/SentryWeakMap.h"
// File-manager tests also need these declarations without the V9 profiler wrapper's guards.
#import "SentryFileManager+Test.h"
#if !SDK_V10
#    import "../../../Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_MachException.h"
#    import "../../../Sources/SentryCrash/Recording/SentryCrashCachedData.h"
#    import "../../../Sources/SentryCrash/Recording/SentryCrashDoctor.h"
#    import "../../../Sources/SentryCrash/Recording/SentryCrashReport.h"
#    import "../../../Sources/SentryCrash/Recording/SentryCrashReportStore.h"
#    import "../../../Sources/SentryCrash/Recording/Tools/SentryCrashCxaThrowSwapper.h"
#    import "../../../Sources/SentryCrash/Recording/Tools/SentryCrashJSONCodecObjC.h"
#    import "../../../Sources/SentryCrash/Recording/Tools/SentryCrashStackCursor_Backtrace.h"
#    import "../../../Sources/SentryCrash/Recording/Tools/SentryCrashStackCursor_SelfThread.h"
#endif

#import "SentryTestClientWrapper.h"
#import "SentryTestHubWrapper.h"
#import "SentryTestProfilerWrapper.h"
#import "SentryTestStateWrapper.h"

#import "ExceptionCatcher.h"
#import "MockUIScene.h"
#import "NSData+Unzip.h"
#import "SentryBooleanSerialization.h"
#import "SentryCrashBinaryImageCache+Test.h"
#import "SentryCrashBinaryImageCacheTestHelper.h"
#import "SentryCrashScopeHelper.h"
#import "SentryInitializeForGettingSubclassesNotCalled.h"
#import "SentryInvalidJSONString.h"
#import "SentryLogTestHelper.h"
#import "SentrySanitizerUtils+Tests.h"
#import "SentryTestObjCRuntimeWrapper.h"
#import "SentryTracer+Test.h"
#import "TestSentrySpan.h"
#import "URLSessionTaskMock.h"
