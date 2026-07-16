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
    XCTAssertTrue(options.urlQueryParams);
#endif
}

#pragma mark - Get/Set

- (void)testurlQueryParams_whenSetToNo_shouldReturnFalse
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    options.urlQueryParams = NO;
    XCTAssertFalse(options.urlQueryParams);
#endif
}

- (void)testurlQueryParams_whenSetToNoThenYes_shouldReturnTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    options.urlQueryParams = NO;
    options.urlQueryParams = YES;
    XCTAssertTrue(options.urlQueryParams);
#endif
}

@end
