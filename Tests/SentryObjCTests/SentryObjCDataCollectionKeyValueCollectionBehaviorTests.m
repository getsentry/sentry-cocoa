@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionKeyValueCollectionBehaviorTests : XCTestCase
@end

@implementation SentryObjCDataCollectionKeyValueCollectionBehaviorTests

#pragma mark - Factory methods

- (void)testOff_shouldHaveOffMode
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior off];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeOff);
    XCTAssertEqual(behavior.terms.count, 0u);
#endif
}

- (void)testDenyList_shouldHaveDenyListMode
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior denyList];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(behavior.terms.count, 0u);
#endif
}

- (void)testDenyListWithTerms_shouldStoreTerms
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior
            denyListWithTerms:@[ @"x-custom", @"secret" ]];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(behavior.terms.count, 2u);
    XCTAssertTrue([behavior.terms containsObject:@"x-custom"]);
    XCTAssertTrue([behavior.terms containsObject:@"secret"]);
#endif
}

- (void)testAllowListWithTerms_shouldStoreTerms
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionKeyValueCollectionBehavior *behavior =
        [SentryObjCDataCollectionKeyValueCollectionBehavior
            allowListWithTerms:@[ @"content-type" ]];
    XCTAssertEqual(behavior.mode, SentryObjCDataCollectionKeyValueCollectionModeAllowList);
    XCTAssertEqual(behavior.terms.count, 1u);
    XCTAssertEqualObjects(behavior.terms.firstObject, @"content-type");
#endif
}

@end
