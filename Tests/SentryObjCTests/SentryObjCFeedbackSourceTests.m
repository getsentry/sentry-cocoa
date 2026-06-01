@import SentryObjC;
@import XCTest;

@interface SentryObjCFeedbackSourceTests : XCTestCase
@end

@implementation SentryObjCFeedbackSourceTests

- (void)testFeedbackSource_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCFeedbackSourceWidget, (NSInteger)0);
    XCTAssertEqual(SentryObjCFeedbackSourceCustom, (NSInteger)1);
}

- (void)testFeedbackSource_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCFeedbackSource roundTripped
        = (SentryObjCFeedbackSource)SentryObjCFeedbackSourceCustom;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCFeedbackSourceCustom);
}

@end
