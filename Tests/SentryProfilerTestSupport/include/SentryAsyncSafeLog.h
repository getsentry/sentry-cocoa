// Expose the SDK's logging macros to package tests without a cross-target header search path.
// The legacy C header includes libc inside extern "C". Newer libc++ module maps diagnose
// those includes when C++ modules are enabled for the package's Objective-C++ tests.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmodule-import-in-extern-c"
#import "../../../Sources/Sentry/SentryAsyncSafeLog.h"
#pragma clang diagnostic pop
