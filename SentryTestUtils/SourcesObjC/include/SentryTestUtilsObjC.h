// Module entry point shared by SwiftPM and Xcode. Import headers needed by Swift test consumers
// here; implementation-only headers stay beside their .m files, outside include/.
//
// Private SDK dependencies use same-named forwarding headers in SourcesObjC/. Keep them out of
// this entry point so their declarations do not enter the Swift module. SwiftPM's target-local
// .headerSearchPath(".") resolves nested imports such as SentryLogC.h -> SentryAsyncSafeLog.h
// without adding whole SDK source directories to the search path. A private aggregate header
// cannot replace the forwarding headers because SDK imports reference their exact filenames.

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
