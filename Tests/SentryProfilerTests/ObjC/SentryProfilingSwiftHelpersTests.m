@import XCTest;
#import "SentryProfiler+Private.h"
#import "SentryProfilerTestConditionals.h"
#import "SentryProfilingSwiftHelpers.h"
#import "SentrySDKInternal.h"
#import <objc/runtime.h>
#if SWIFT_PACKAGE
#    import "SentrySwift.h"
#else
@import Sentry;
#endif

@interface SentryProfilingSwiftHelpersTests : XCTestCase
@end

@implementation SentryProfilingSwiftHelpersTests

#if SENTRY_PROFILER_TESTS_SUPPORTED

- (void)testLaunchBootstrap_whenSDKIsLinked_shouldBeOwnedBySDKNotProfiler
{
    // -- Act --
    Method sdkLoad = class_getClassMethod([SentrySDKInternal class], @selector(load));
    Method profilerLoad = class_getClassMethod([SentryProfiler class], @selector(load));
    Method inheritedLoad = class_getClassMethod([NSObject class], @selector(load));

    // -- Assert --
    XCTAssertNotEqual(sdkLoad, (Method)NULL);
    XCTAssertNotEqual(sdkLoad, inheritedLoad);
    XCTAssertEqual(profilerLoad, inheritedLoad);
}

- (void)testProfilingIdFromSentryId_whenConvertingSDKIdentifier_shouldPreserveUUID
{
    // -- Arrange --
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"01234567-89AB-CDEF-0123-456789ABCDEF"];
    SentryId *sentryId = [[SentryId alloc] initWithUuid:uuid];

    // -- Act --
    SentryProfilingId *profilingId = sentry_profilingIdFromSentryId(sentryId);

    // -- Assert --
    XCTAssertEqualObjects(profilingId.uuid, uuid);
    XCTAssertEqualObjects(profilingId.stringValue, sentryId.sentryIdString);
    XCTAssertEqualObjects(profilingId, sentry_profilingIdFromSentryId(sentryId));
}

- (void)testProfilingIdFromSentryId_whenSDKIdentifierIsEmpty_shouldPreserveEmptyUUID
{
    // -- Arrange --
    SentryId *sentryId = SentryId.empty;

    // -- Act --
    SentryProfilingId *profilingId = sentry_profilingIdFromSentryId(sentryId);

    // -- Assert --
    XCTAssertEqualObjects(profilingId.stringValue, @"00000000000000000000000000000000");
}

#endif

@end
