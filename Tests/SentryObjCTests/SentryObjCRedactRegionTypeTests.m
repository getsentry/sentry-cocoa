@import SentryObjC;
@import XCTest;

@interface SentryObjCRedactRegionTypeTests : XCTestCase
@end

@implementation SentryObjCRedactRegionTypeTests

- (void)testRedactRegionType_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCRedactRegionTypeRedact, (NSInteger)0);
    XCTAssertEqual(SentryObjCRedactRegionTypeClipOut, (NSInteger)1);
    XCTAssertEqual(SentryObjCRedactRegionTypeClipBegin, (NSInteger)2);
    XCTAssertEqual(SentryObjCRedactRegionTypeClipEnd, (NSInteger)3);
    XCTAssertEqual(SentryObjCRedactRegionTypeRedactSwiftUI, (NSInteger)4);
}

- (void)testRedactRegionType_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCRedactRegionType roundTripped
        = (SentryObjCRedactRegionType)SentryObjCRedactRegionTypeClipBegin;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCRedactRegionTypeClipBegin);
}

@end
