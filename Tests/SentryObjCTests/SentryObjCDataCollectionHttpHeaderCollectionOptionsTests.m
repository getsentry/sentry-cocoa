@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionHttpHeaderCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionHttpHeaderCollectionOptionsTests

#pragma mark - Defaults

- (void)testInit_shouldDefaultToDenyList
{
    SentryObjCDataCollectionHttpHeaderCollectionOptions *options =
        [[SentryObjCDataCollectionHttpHeaderCollectionOptions alloc] init];
    XCTAssertEqual(options.request.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(options.response.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
}

#pragma mark - Get/Set

- (void)testRequest_whenSetToOff_shouldReturnOff
{
    SentryObjCDataCollectionHttpHeaderCollectionOptions *options =
        [[SentryObjCDataCollectionHttpHeaderCollectionOptions alloc] init];
    options.request = [SentryObjCDataCollectionKeyValueCollectionBehavior off];
    XCTAssertEqual(options.request.mode, SentryObjCDataCollectionKeyValueCollectionModeOff);
}

- (void)testResponse_whenSetToAllowList_shouldReturnAllowList
{
    SentryObjCDataCollectionHttpHeaderCollectionOptions *options =
        [[SentryObjCDataCollectionHttpHeaderCollectionOptions alloc] init];
    options.response = [SentryObjCDataCollectionKeyValueCollectionBehavior
        allowListWithTerms:@[ @"content-type" ]];
    XCTAssertEqual(options.response.mode, SentryObjCDataCollectionKeyValueCollectionModeAllowList);
    XCTAssertEqualObjects(options.response.terms.firstObject, @"content-type");
}

@end
