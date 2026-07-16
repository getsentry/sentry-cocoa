@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionGraphQLCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionGraphQLCollectionOptionsTests

#pragma mark - Defaults

- (void)testInit_shouldDefaultToTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionGraphQLCollectionOptions *options =
        [[SentryObjCDataCollectionGraphQLCollectionOptions alloc] init];
    XCTAssertTrue(options.document);
    XCTAssertTrue(options.variables);
#endif
}

#pragma mark - Get/Set

- (void)testDocument_whenSetToNo_shouldReturnFalse
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionGraphQLCollectionOptions *options =
        [[SentryObjCDataCollectionGraphQLCollectionOptions alloc] init];
    options.document = NO;
    XCTAssertFalse(options.document);
#endif
}

- (void)testVariables_whenSetToNo_shouldReturnFalse
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionGraphQLCollectionOptions *options =
        [[SentryObjCDataCollectionGraphQLCollectionOptions alloc] init];
    options.variables = NO;
    XCTAssertFalse(options.variables);
#endif
}

@end
