#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCReplayQualityTests : XCTestCase
@end

@implementation SentryObjCReplayQualityTests

- (void)testReplayQuality_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCReplayQualityLow, (NSInteger)0);
    XCTAssertEqual(SentryObjCReplayQualityMedium, (NSInteger)1);
    XCTAssertEqual(SentryObjCReplayQualityHigh, (NSInteger)2);
}

- (void)testReplayQuality_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCReplayQuality roundTripped = (SentryObjCReplayQuality)SentryObjCReplayQualityHigh;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCReplayQualityHigh);
}

@end
