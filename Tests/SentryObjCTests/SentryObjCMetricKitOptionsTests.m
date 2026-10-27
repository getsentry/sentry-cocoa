@import SentryObjC;
@import XCTest;

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

@interface SentryObjCMetricKitOptionsTests : XCTestCase
@end

@implementation SentryObjCMetricKitOptionsTests

- (void)testEnabledDiagnosticReports_whenDefault_shouldDependOnSDKVersion
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
#    if SDK_V10
    XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportCPUException
            | SentryObjCMetricKitDiagnosticReportDiskWriteException
            | SentryObjCMetricKitDiagnosticReportHang
            | SentryObjCMetricKitDiagnosticReportAppLaunch);
#    else
    XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportNone);
#    endif // SDK_V10
}

- (void)testEnabledDiagnosticReports_whenSetToEveryReport_shouldReturnEveryReport
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    SentryObjCMetricKitDiagnosticReport all = SentryObjCMetricKitDiagnosticReportCrash
        | SentryObjCMetricKitDiagnosticReportHang | SentryObjCMetricKitDiagnosticReportCPUException
        | SentryObjCMetricKitDiagnosticReportDiskWriteException
        | SentryObjCMetricKitDiagnosticReportAppLaunch;

    // -- Act --
    options.experimental.metrickit.enabledDiagnosticReports = all;

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, all);
}

- (void)testEnabledDiagnosticReports_whenSetToNone_shouldReturnNone
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.experimental.metrickit.enabledDiagnosticReports
        = SentryObjCMetricKitDiagnosticReportHang;

    // -- Act --
    options.experimental.metrickit.enabledDiagnosticReports
        = SentryObjCMetricKitDiagnosticReportNone;

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportNone);
}

- (void)testEnabledDiagnosticReports_whenUnknownBitsSet_shouldIgnoreThem
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.metrickit.enabledDiagnosticReports
        = SentryObjCMetricKitDiagnosticReportHang | (1 << 10);

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportHang);
}

- (void)testEnabledDiagnosticReports_whenSetOnOneAccessor_shouldBeVisibleOnAnother
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    SentryObjCMetricKitOptions *first = options.experimental.metrickit;

    // -- Act --
    first.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportCrash;

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportCrash);
}

@end

#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
