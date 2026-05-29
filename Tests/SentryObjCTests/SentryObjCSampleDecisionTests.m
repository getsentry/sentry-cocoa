@import SentryObjC;
@import XCTest;

@interface SentryObjCSampleDecisionTests : XCTestCase
@end

@implementation SentryObjCSampleDecisionTests

- (void)testSampleDecision_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCSampleDecisionUndecided, (NSUInteger)0);
    XCTAssertEqual(SentryObjCSampleDecisionYes, (NSUInteger)1);
    XCTAssertEqual(SentryObjCSampleDecisionNo, (NSUInteger)2);
}

- (void)testSampleDecision_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCSampleDecision roundTripped = (SentryObjCSampleDecision)SentryObjCSampleDecisionNo;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCSampleDecisionNo);
}

@end
