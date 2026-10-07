@import SentryObjC;
@import XCTest;

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

@interface SentryObjCMetricKitOptionsTests : XCTestCase
@end

@implementation SentryObjCMetricKitOptionsTests

- (void)testInit_shouldCreateInstance
{
    // -- Act --
    SentryObjCMetricKitOptions *options = [[SentryObjCMetricKitOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options);
}

- (void)testEnabledDiagnosticReports_whenDefault_shouldDependOnSDKVersion
{
    // -- Arrange --
    SentryObjCMetricKitOptions *options = [[SentryObjCMetricKitOptions alloc] init];

    // -- Assert --
#    if SDK_V10
    XCTAssertEqual(options.enabledDiagnosticReports,
        SentryObjCMetricKitDiagnosticReportCPUException
            | SentryObjCMetricKitDiagnosticReportDiskWriteException
            | SentryObjCMetricKitDiagnosticReportHang);
#    else
    XCTAssertEqual(options.enabledDiagnosticReports, SentryObjCMetricKitDiagnosticReportNone);
#    endif // SDK_V10
}

- (void)testEnabledDiagnosticReports_whenSetToEveryReport_shouldReturnEveryReport
{
    // -- Arrange --
    SentryObjCMetricKitOptions *options = [[SentryObjCMetricKitOptions alloc] init];
    SentryObjCMetricKitDiagnosticReport all = SentryObjCMetricKitDiagnosticReportCrash
        | SentryObjCMetricKitDiagnosticReportHang | SentryObjCMetricKitDiagnosticReportCPUException
        | SentryObjCMetricKitDiagnosticReportDiskWriteException;

    // -- Act --
    options.enabledDiagnosticReports = all;

    // -- Assert --
    XCTAssertEqual(options.enabledDiagnosticReports, all);
}

- (void)testEnabledDiagnosticReports_whenSetToNone_shouldReturnNone
{
    // -- Arrange --
    SentryObjCMetricKitOptions *options = [[SentryObjCMetricKitOptions alloc] init];
    options.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportHang;

    // -- Act --
    options.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportNone;

    // -- Assert --
    XCTAssertEqual(options.enabledDiagnosticReports, SentryObjCMetricKitDiagnosticReportNone);
}

- (void)testEnabledDiagnosticReports_whenUnknownBitsSet_shouldIgnoreThem
{
    // -- Arrange --
    SentryObjCMetricKitOptions *options = [[SentryObjCMetricKitOptions alloc] init];

    // -- Act --
    options.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportHang | (1 << 10);

    // -- Assert --
    XCTAssertEqual(options.enabledDiagnosticReports, SentryObjCMetricKitDiagnosticReportHang);
}

@end

#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
