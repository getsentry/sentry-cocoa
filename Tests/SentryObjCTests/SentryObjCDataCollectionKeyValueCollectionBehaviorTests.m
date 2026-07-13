@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionKeyValueCollectionBehaviorTests : XCTestCase
@end

@implementation SentryObjCDataCollectionKeyValueCollectionBehaviorTests

#pragma mark - Factory methods

- (void)testOff_shouldHaveOffMode
{
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior off];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeOff);
    XCTAssertEqual(behavior.terms.count, 0u);
}

- (void)testDenyList_shouldHaveDenyListMode
{
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior denyList];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(behavior.terms.count, 0u);
}

- (void)testDenyListWithTerms_shouldStoreTerms
{
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior
            denyListWithTerms:@[ @"x-custom", @"secret" ]];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(behavior.terms.count, 2u);
    XCTAssertTrue([behavior.terms containsObject:@"x-custom"]);
    XCTAssertTrue([behavior.terms containsObject:@"secret"]);
}

- (void)testAllowListWithTerms_shouldStoreTerms
{
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior
            allowListWithTerms:@[ @"content-type" ]];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeAllowList);
    XCTAssertEqual(behavior.terms.count, 1u);
    XCTAssertEqualObjects(behavior.terms.firstObject, @"content-type");
}

@end
