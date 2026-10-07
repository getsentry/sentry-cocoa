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

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
#    pragma mark - metricKit

- (void)testMetricKit_whenDefault_shouldDependOnSDKVersion
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
#    if SDK_V10
    XCTAssertEqual(options.experimental.metricKit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportCPUException
            | SentryObjCMetricKitDiagnosticReportDiskWriteException
            | SentryObjCMetricKitDiagnosticReportHang);
#    else
    XCTAssertEqual(options.experimental.metricKit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportNone);
#    endif // SDK_V10
}

- (void)testMetricKit_whenReportsSetInPlace_shouldWriteThroughToOptions
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.metricKit.enabledDiagnosticReports
        = SentryObjCMetricKitDiagnosticReportHang | SentryObjCMetricKitDiagnosticReportCrash;

    // -- Assert --
    XCTAssertEqual(options.experimental.metricKit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportHang | SentryObjCMetricKitDiagnosticReportCrash);
}

- (void)testMetricKit_whenReplaced_shouldUseNewOptions
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    SentryObjCMetricKitOptions *metricKit = [[SentryObjCMetricKitOptions alloc] init];
    metricKit.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportDiskWriteException;

    // -- Act --
    options.experimental.metricKit = metricKit;

    // -- Assert --
    XCTAssertEqual(options.experimental.metricKit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportDiskWriteException);
}
#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

@end
