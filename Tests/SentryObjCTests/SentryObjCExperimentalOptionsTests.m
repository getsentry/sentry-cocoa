@import SentryObjC;
@import XCTest;

@interface SentryObjCExperimentalOptionsTests : XCTestCase
@end

@implementation SentryObjCExperimentalOptionsTests

#pragma mark - MetricKit

- (void)testHangReportingMode_whenDefault_shouldUseLegacy
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.hangReportingMode,
        SentryObjCMetricKitHangReportingModeLegacy);
}

- (void)testHangReportingMode_whenToggled_shouldRetainMode
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.metrickit.hangReportingMode = SentryObjCMetricKitHangReportingModeCulprit;

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.hangReportingMode,
        SentryObjCMetricKitHangReportingModeCulprit);

    // -- Act --
    options.experimental.metrickit.hangReportingMode = SentryObjCMetricKitHangReportingModeLegacy;

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.hangReportingMode,
        SentryObjCMetricKitHangReportingModeLegacy);
}

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
    // -- Act --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options);
}

#if !SDK_V10
#    pragma mark - enableUnhandledCPPExceptionsV2

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

#endif // !SDK_V10

#pragma mark - enableNewURLLoaderSwizzling

- (void)testEnableNewURLLoaderSwizzling_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.experimental.enableNewURLLoaderSwizzling);
}

- (void)testEnableNewURLLoaderSwizzling_whenToggled_shouldRetainValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.enableNewURLLoaderSwizzling = YES;

    // -- Assert --
    XCTAssertTrue(options.experimental.enableNewURLLoaderSwizzling);

    // -- Act --
    options.experimental.enableNewURLLoaderSwizzling = NO;

    // -- Assert --
    XCTAssertFalse(options.experimental.enableNewURLLoaderSwizzling);
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
