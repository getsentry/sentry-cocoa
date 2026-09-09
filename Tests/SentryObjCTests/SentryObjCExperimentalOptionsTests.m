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

#if !SDK_V10
#    pragma mark - enableWatchdogTerminationsV2

- (void)testEnableWatchdogTerminationsV2_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // -- Assert --
    XCTAssertFalse(options.enableWatchdogTerminationsV2);
#    pragma clang diagnostic pop
}

- (void)testEnableWatchdogTerminationsV2_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // -- Act --
    options.enableWatchdogTerminationsV2 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableWatchdogTerminationsV2);
#    pragma clang diagnostic pop
}
#endif

@end
