// Module entry point shared by SwiftPM and Xcode. Import headers needed by Swift test consumers
// here; implementation-only headers stay beside their .m files, outside include/.
//
// Implementation-only SDK dependencies use same-named forwarding headers in SourcesObjC/.
// Keep those out of this entry point. SwiftPM's target-local
// .headerSearchPath(".") resolves nested imports such as SentryLogC.h -> SentryAsyncSafeLog.h
// without adding whole SDK source directories to the search path. A private aggregate header
// cannot replace the forwarding headers because SDK imports reference their exact filenames.

#import "SentryTestUtilsObjC-SDKHeaders.h"

// Test-only selectors on the real SDK classes.
#import "SentryClient+TestInit.h"
#import "SentryHub+Test.h"
#import "SentrySDKInternal+Tests.h"
#import "SentrySDKTestAccess.h"

// Test helpers.
#import "SentryTestClientWrapper.h"
#import "SentryTestHubWrapper.h"
#import "SentryTestProfilerWrapper.h"
#import "SentryTestSDKBridge.h"
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
