// Additional SDK declarations needed by Swift tests in both Xcode and SwiftPM.
// Import the original headers; their implementations remain in the SDK.
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
