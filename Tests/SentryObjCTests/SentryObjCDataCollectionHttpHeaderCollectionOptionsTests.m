@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionHttpHeaderCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionHttpHeaderCollectionOptionsTests

#pragma mark - Defaults

- (void)testInit_shouldDefaultToDenyList
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionHttpHeaderCollectionOptions *options =
        [[SentryObjCDataCollectionHttpHeaderCollectionOptions alloc] init];
    XCTAssertEqual(options.request.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(options.response.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
#endif
}

#pragma mark - Get/Set

- (void)testRequest_whenSetToOff_shouldReturnOff
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionHttpHeaderCollectionOptions *options =
        [[SentryObjCDataCollectionHttpHeaderCollectionOptions alloc] init];
    options.request = [SentryObjCDataCollectionKeyValueCollectionBehavior off];
    XCTAssertEqual(options.request.mode, SentryObjCDataCollectionKeyValueCollectionModeOff);
#endif
}

- (void)testResponse_whenSetToAllowList_shouldReturnAllowList
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionHttpHeaderCollectionOptions *options =
        [[SentryObjCDataCollectionHttpHeaderCollectionOptions alloc] init];
    options.response = [SentryObjCDataCollectionKeyValueCollectionBehavior
        allowListWithTerms:@[ @"content-type" ]];
    XCTAssertEqual(options.response.mode, SentryObjCDataCollectionKeyValueCollectionModeAllowList);
    XCTAssertEqualObjects(options.response.terms.firstObject, @"content-type");
#endif
}

@end
