@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionDatabaseCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionDatabaseCollectionOptionsTests

#pragma mark - Defaults

- (void)testInit_shouldDefaultToTrue
{
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    XCTAssertTrue(options.queryParams);
}

#pragma mark - Get/Set

- (void)testQueryParams_whenSetToNo_shouldReturnFalse
{
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    options.queryParams = NO;
    XCTAssertFalse(options.queryParams);
}

- (void)testQueryParams_whenSetToNoThenYes_shouldReturnTrue
{
    SentryObjCDataCollectionDatabaseCollectionOptions *options =
        [[SentryObjCDataCollectionDatabaseCollectionOptions alloc] init];
    options.queryParams = NO;
    options.queryParams = YES;
    XCTAssertTrue(options.queryParams);
}

@end
