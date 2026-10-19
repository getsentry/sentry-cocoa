// Module entry point shared by SwiftPM and Xcode. Import headers needed by Swift test consumers
// here; implementation-only headers stay beside their .m files, outside include/.
//
// Implementation-only SDK dependencies use same-named forwarding headers in SourcesObjC/.
// Keep those out of this entry point. SwiftPM's target-local
// .headerSearchPath(".") resolves nested imports such as SentryLogC.h -> SentryAsyncSafeLog.h
// without adding whole SDK source directories to the search path. A private aggregate header
// cannot replace the forwarding headers because SDK imports reference their exact filenames.

#import "SentryTestUtilsObjC-SDKHeaders.h"

// Import adapted SDK selectors before subclasses so Swift inherits their initializers.
#import "Wrappers/SentryClient+PrivateWrapper.h"
#import "Wrappers/SentryHub+PrivateWrapper.h"
#import "Wrappers/SentryScope+PrivateWrapper.h"
#import "Wrappers/SentrySpanInternal+PrivateWrapper.h"
#import "Wrappers/SentryTraceContext+PrivateWrapper.h"
#import "Wrappers/SentryTracer+PrivateWrapper.h"
#import "Wrappers/SentryTransactionContext+PrivateWrapper.h"

// Existing helpers retain their paths until the test-support layout migration.
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
#import "SentrySDKInternal+Tests.h"
#import "SentrySanitizerUtils+Tests.h"
#import "SentryTestClientWrapper.h"
#import "SentryTestHubWrapper.h"
#import "SentryTestObjCRuntimeWrapper.h"
#import "SentryTestProfilerWrapper.h"
#import "SentryTestStateWrapper.h"
#import "SentryTracer+Test.h"
#import "TestSentrySpan.h"
#import "URLSessionTaskMock.h"
