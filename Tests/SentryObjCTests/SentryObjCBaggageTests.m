@import SentryObjC;
@import XCTest;

@interface SentryObjCBaggageTests : XCTestCase
@end

@implementation SentryObjCBaggageTests

- (void)testHttpHeaderField_shouldReturnBaggage
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCBaggage.httpHeaderField, @"baggage");
}

@end
