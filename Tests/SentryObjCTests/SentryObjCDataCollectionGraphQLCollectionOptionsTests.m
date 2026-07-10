@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionGraphQLCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionGraphQLCollectionOptionsTests

#pragma mark - Defaults

- (void)testInit_shouldDefaultToTrue
{
    SentryObjCDataCollectionGraphQLCollectionOptions *options =
        [[SentryObjCDataCollectionGraphQLCollectionOptions alloc] init];
    XCTAssertTrue(options.document);
    XCTAssertTrue(options.variables);
}

#pragma mark - Get/Set

- (void)testDocument_whenSetToNo_shouldReturnFalse
{
    SentryObjCDataCollectionGraphQLCollectionOptions *options =
        [[SentryObjCDataCollectionGraphQLCollectionOptions alloc] init];
    options.document = NO;
    XCTAssertFalse(options.document);
}

- (void)testVariables_whenSetToNo_shouldReturnFalse
{
    SentryObjCDataCollectionGraphQLCollectionOptions *options =
        [[SentryObjCDataCollectionGraphQLCollectionOptions alloc] init];
    options.variables = NO;
    XCTAssertFalse(options.variables);
}

@end
