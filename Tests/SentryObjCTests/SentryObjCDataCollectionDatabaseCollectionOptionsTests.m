@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionDatabaseCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionDatabaseCollectionOptionsTests

#pragma mark - Defaults

- (void)testInit_shouldDefaultToTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    XCTAssertTrue(options.queryParams);
#endif
}

#pragma mark - Get/Set

- (void)testQueryParams_whenSetToNo_shouldReturnFalse
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    options.queryParams = NO;
    XCTAssertFalse(options.queryParams);
#endif
}

- (void)testQueryParams_whenSetToNoThenYes_shouldReturnTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    options.queryParams = NO;
    options.queryParams = YES;
    XCTAssertTrue(options.queryParams);
#endif
}

@end
