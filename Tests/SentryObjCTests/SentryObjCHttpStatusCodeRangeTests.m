#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCHttpStatusCodeRangeTests : XCTestCase
@end

@implementation SentryObjCHttpStatusCodeRangeTests

#pragma mark - initWithMin:max:

- (void)testInitWithMinMax_shouldReturnNonNil
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range = [[SentryObjCHttpStatusCodeRange alloc] initWithMin:400
                                                                                          max:499];

    // -- Assert --
    XCTAssertNotNil(range);
}

- (void)testInitWithMinMax_shouldSetMin
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range = [[SentryObjCHttpStatusCodeRange alloc] initWithMin:400
                                                                                          max:499];

    // -- Assert --
    XCTAssertEqual(range.min, 400);
}

- (void)testInitWithMinMax_shouldSetMax
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range = [[SentryObjCHttpStatusCodeRange alloc] initWithMin:400
                                                                                          max:499];

    // -- Assert --
    XCTAssertEqual(range.max, 499);
}

- (void)testInitWithMinMax_whenFullRange_shouldSetMinAndMax
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range = [[SentryObjCHttpStatusCodeRange alloc] initWithMin:200
                                                                                          max:599];

    // -- Assert --
    XCTAssertEqual(range.min, 200);
    XCTAssertEqual(range.max, 599);
}

#pragma mark - initWithStatusCode:

- (void)testInitWithStatusCode_shouldReturnNonNil
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range =
        [[SentryObjCHttpStatusCodeRange alloc] initWithStatusCode:500];

    // -- Assert --
    XCTAssertNotNil(range);
}

- (void)testInitWithStatusCode_shouldSetMinToStatusCode
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range =
        [[SentryObjCHttpStatusCodeRange alloc] initWithStatusCode:500];

    // -- Assert --
    XCTAssertEqual(range.min, 500);
}

- (void)testInitWithStatusCode_shouldSetMaxToStatusCode
{
    // -- Act --
    SentryObjCHttpStatusCodeRange *range =
        [[SentryObjCHttpStatusCodeRange alloc] initWithStatusCode:500];

    // -- Assert --
    XCTAssertEqual(range.max, 500);
}

@end
