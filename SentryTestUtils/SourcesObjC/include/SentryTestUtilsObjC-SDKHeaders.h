// Additional SDK declarations needed by Swift tests in both Xcode and SwiftPM.
// Import the original headers; their implementations remain in the SDK.
// Keep generated Swift interfaces out of this module to avoid import cycles.

// Load the owning module before categories so Swift retains the base types' module identity.
@import _SentryPrivate;
#import "../../../Sources/Sentry/SentryAsyncSafeLog.h"
#import "../../../Sources/Sentry/SentryFileIO.h"
#import "../../../Sources/Sentry/SentryJSONStreamWriter.h"
#import "../../../Sources/Sentry/include/NSMutableDictionary+Sentry.h"
#import "../../../Sources/Sentry/include/SentryCrashStackEntryMapper.h"
#import "../../../Sources/Sentry/include/SentryFormatter.h"
#import "../../../Sources/Sentry/include/SentryGeo+Private.h"
#import "../../../Sources/Sentry/include/SentryInternalNotificationNames.h"
#import "../../../Sources/Sentry/include/SentrySampleDecision+Private.h"
#import "../../../Sources/Sentry/include/SentryTracer+Private.h"
#import "../../../Sources/Sentry/include/SentryTransportFactory.h"
#import "../../../Sources/Sentry/include/SentryWeakMap.h"
// File-manager tests also need these declarations without the V9 profiler wrapper's guards.
#import "SentryFileManager+Test.h"
