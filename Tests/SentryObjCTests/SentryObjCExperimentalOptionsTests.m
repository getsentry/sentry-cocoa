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

#pragma mark - enableReplayNetworkDetailsCapturing

- (void)testEnableReplayNetworkDetailsCapturing_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.enableReplayNetworkDetailsCapturing);
}

- (void)testEnableReplayNetworkDetailsCapturing_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.enableReplayNetworkDetailsCapturing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableReplayNetworkDetailsCapturing);
}

#pragma mark - dataCollection

- (void)testDataCollection_whenDefault_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options.dataCollection);
}

- (void)testDataCollection_whenDefault_shouldHaveSpecDefaults
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertTrue(options.dataCollection.userInfo);
    XCTAssertEqual(options.dataCollection.httpBodies, SentryObjCDataCollectionHttpBodyTypeAll);
    XCTAssertTrue(options.dataCollection.stackFrameVariables);
    XCTAssertEqual(options.dataCollection.frameContextLines, 5u);
}

- (void)testDataCollection_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];
    SentryObjCDataCollectionOptions *dc = [[SentryObjCDataCollectionOptions alloc] init];
    dc.userInfo = NO;

    // -- Act --
    options.dataCollection = dc;

    // -- Assert --
    XCTAssertFalse(options.dataCollection.userInfo);
}

@end
