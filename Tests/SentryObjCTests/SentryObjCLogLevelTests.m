@import SentryObjC;
@import XCTest;

@interface SentryObjCLogLevelTests : XCTestCase
@end

@implementation SentryObjCLogLevelTests

- (void)testLogLevel_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCLogLevelTrace, (NSInteger)0);
    XCTAssertEqual(SentryObjCLogLevelDebug, (NSInteger)1);
    XCTAssertEqual(SentryObjCLogLevelInfo, (NSInteger)2);
    XCTAssertEqual(SentryObjCLogLevelWarn, (NSInteger)3);
    XCTAssertEqual(SentryObjCLogLevelError, (NSInteger)4);
    XCTAssertEqual(SentryObjCLogLevelFatal, (NSInteger)5);
}

- (void)testLogLevel_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCLogLevel roundTripped = (SentryObjCLogLevel)SentryObjCLogLevelWarn;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCLogLevelWarn);
}

@end
