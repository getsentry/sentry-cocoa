@import SentryObjC;
@import XCTest;

@interface SentryObjCTransactionNameSourceTests : XCTestCase
@end

@implementation SentryObjCTransactionNameSourceTests

- (void)testTransactionNameSource_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCTransactionNameSourceCustom, (NSInteger)0);
    XCTAssertEqual(SentryObjCTransactionNameSourceUrl, (NSInteger)1);
    XCTAssertEqual(SentryObjCTransactionNameSourceRoute, (NSInteger)2);
    XCTAssertEqual(SentryObjCTransactionNameSourceView, (NSInteger)3);
    XCTAssertEqual(SentryObjCTransactionNameSourceComponent, (NSInteger)4);
    XCTAssertEqual(SentryObjCTransactionNameSourceTask, (NSInteger)5);
}

- (void)testTransactionNameSource_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCTransactionNameSource roundTripped
        = (SentryObjCTransactionNameSource)SentryObjCTransactionNameSourceRoute;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCTransactionNameSourceRoute);
}

@end
