// Xcode-only declarations that still depend on Swift-owned types across the Objective-C/Swift
// boundary. Keep these here until their mixed-language APIs are migrated to SwiftPM.
// Shared SDK test declarations belong in SentryTestUtilsObjC-SDKHeaders.h, exposed through
// SentryTestUtilsObjC in both build systems; import other declarations from their owning modules.
#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

// Load the Objective-C base declarations before their generated Swift interface.
@import _SentryPrivate;
#import "SentryCrashStackEntryMapper.h"
#import "SentrySwift.h"
