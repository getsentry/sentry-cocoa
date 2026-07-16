@import SentryObjC;
@import XCTest;

@interface SentryObjCExperimentalOptionsTests : XCTestCase
@end

@implementation SentryObjCExperimentalOptionsTests

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
    // -- Act --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options);
}

#pragma mark - enableUnhandledCPPExceptionsV2

- (void)testEnableUnhandledCPPExceptionsV2_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.enableUnhandledCPPExceptionsV2);
}

- (void)testEnableUnhandledCPPExceptionsV2_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.enableUnhandledCPPExceptionsV2 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableUnhandledCPPExceptionsV2);
}

- (void)testEnableUnhandledCPPExceptionsV2_whenSetToNo_shouldReturnFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];
    options.enableUnhandledCPPExceptionsV2 = YES;

    // -- Act --
    options.enableUnhandledCPPExceptionsV2 = NO;

    // -- Assert --
    XCTAssertFalse(options.enableUnhandledCPPExceptionsV2);
}

#pragma mark - enableWatchdogTerminationsV2

- (void)testEnableWatchdogTerminationsV2_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.enableWatchdogTerminationsV2);
}

- (void)testEnableWatchdogTerminationsV2_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.enableWatchdogTerminationsV2 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableWatchdogTerminationsV2);
}

#pragma mark - dataCollection

- (void)testDataCollection_whenDefault_shouldReturnNotNil
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options.dataCollection);
#endif
}

- (void)testDataCollection_whenDefault_shouldHaveSpecDefaults
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertTrue(options.dataCollection.userInfo);
    XCTAssertEqual(options.dataCollection.httpBodies, SentryObjCDataCollectionHttpBodyTypeAll);
    XCTAssertTrue(options.dataCollection.stackFrameVariables);
    XCTAssertEqual(options.dataCollection.frameContextLines, 5u);
#endif
}

- (void)testDataCollection_whenSet_shouldReturnNewValue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];
    SentryObjCDataCollectionOptions *dc = [[SentryObjCDataCollectionOptions alloc] init];
    dc.userInfo = NO;

    // -- Act --
    options.dataCollection = dc;

    // -- Assert --
    XCTAssertFalse(options.dataCollection.userInfo);
#endif
}

- (void)testDataCollection_whenMutatedInPlace_shouldPropagateToParent
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];
    XCTAssertTrue(options.dataCollection.userInfo);

    // -- Act --
    options.dataCollection.userInfo = NO;

    // -- Assert --
    XCTAssertFalse(options.dataCollection.userInfo);
#endif
}

- (void)testDataCollection_whenSubPropertyMutatedInPlace_shouldPropagateToParent
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.dataCollection.database.queryParams = NO;

    // -- Assert --
    XCTAssertFalse(options.dataCollection.database.queryParams);
#endif
}

- (void)testDataCollection_whenGraphqlMutatedInPlace_shouldPropagateToParent
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.dataCollection.graphql.document = NO;

    // -- Assert --
    XCTAssertFalse(options.dataCollection.graphql.document);
#endif
}

- (void)testDataCollection_whenHttpHeadersMutatedInPlace_shouldPropagateToParent
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.dataCollection.httpHeaders.request =
        [SentryObjCDataCollectionKeyValueCollectionBehavior off];

    // -- Assert --
    XCTAssertEqual(options.dataCollection.httpHeaders.request.mode,
        SentryObjCDataCollectionKeyValueCollectionModeOff);
#endif
}

@end
