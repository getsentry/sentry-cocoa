@import XCTest;
#import "SentryProfilerTestConditionals.h"
#import "SentryProfilingSwiftHelpers.h"
#if SWIFT_PACKAGE
#    import "SentrySwift.h"
#else
@import Sentry;
#endif

@interface SentryProfilingSwiftHelpersTests : XCTestCase
@end

@implementation SentryProfilingSwiftHelpersTests

#if SENTRY_PROFILER_TESTS_SUPPORTED

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
