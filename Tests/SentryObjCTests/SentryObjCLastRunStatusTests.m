@import SentryObjC;
@import XCTest;

@interface SentryObjCLastRunStatusTests : XCTestCase
@end

@implementation SentryObjCLastRunStatusTests

- (void)testLastRunStatus_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCLastRunStatusUnknown, (NSInteger)0);
    XCTAssertEqual(SentryObjCLastRunStatusDidNotCrash, (NSInteger)1);
    XCTAssertEqual(SentryObjCLastRunStatusDidCrash, (NSInteger)2);
}

- (void)testLastRunStatus_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCLastRunStatus roundTripped = (SentryObjCLastRunStatus)SentryObjCLastRunStatusDidCrash;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCLastRunStatusDidCrash);
}

@end
