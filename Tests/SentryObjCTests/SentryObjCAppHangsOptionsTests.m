@import SentryObjC;
@import XCTest;

@interface SentryObjCAppHangsOptionsTests : XCTestCase
@end

@implementation SentryObjCAppHangsOptionsTests

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
    // -- Act --
    SentryObjCAppHangsOptions *options = [[SentryObjCAppHangsOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options);
}

#pragma mark - enableV3

- (void)testEnableV3_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCAppHangsOptions *options = [[SentryObjCAppHangsOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.enableV3);
}

- (void)testEnableV3_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCAppHangsOptions *options = [[SentryObjCAppHangsOptions alloc] init];

    // -- Act --
    options.enableV3 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableV3);
}

#pragma mark - threshold

- (void)testAppHangThreshold_whenDefault_shouldBeTwo
{
    // -- Arrange --
    SentryObjCAppHangsOptions *options = [[SentryObjCAppHangsOptions alloc] init];

    // -- Assert --
    XCTAssertEqual(options.threshold, 2.0);
}

- (void)testAppHangThreshold_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCAppHangsOptions *options = [[SentryObjCAppHangsOptions alloc] init];

    // -- Act --
    options.threshold = 5.0;

    // -- Assert --
    XCTAssertEqual(options.threshold, 5.0);
}

#pragma mark - Access via ExperimentalOptions

- (void)testAccessViaExperimentalOptions_shouldPropagateWrites
{
    // -- Arrange --
    SentryObjCExperimentalOptions *experimental = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    experimental.appHangs.enableV3 = YES;
    experimental.appHangs.threshold = 3.0;

    // -- Assert --
    XCTAssertTrue(experimental.appHangs.enableV3);
    XCTAssertEqual(experimental.appHangs.threshold, 3.0);
}

- (void)testAccessViaOptions_shouldPropagateWrites
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.appHangs.enableV3 = YES;
    options.experimental.appHangs.threshold = 4.0;

    // -- Assert --
    XCTAssertTrue(options.experimental.appHangs.enableV3);
    XCTAssertEqual(options.experimental.appHangs.threshold, 4.0);
}

@end
