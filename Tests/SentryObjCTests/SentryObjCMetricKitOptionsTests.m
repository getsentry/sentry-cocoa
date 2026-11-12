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
        | SentryObjCMetricKitDiagnosticReportAppLaunch
        | SentryObjCMetricKitDiagnosticReportMemoryException;

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

- (void)testEnabledMetricReports_whenDefault_shouldBeNone
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
    XCTAssertEqual(
        options.experimental.metrickit.enabledMetricReports, SentryObjCMetricKitMetricReportNone);
}

- (void)testEnabledMetricReports_whenSetToAll_shouldReturnAll
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.metrickit.enabledMetricReports = SentryObjCMetricKitMetricReportAll;

    // -- Assert --
    XCTAssertEqual(
        options.experimental.metrickit.enabledMetricReports, SentryObjCMetricKitMetricReportAll);
}

- (void)testEnabledMetricReports_whenSetToSomeReports_shouldReturnThem
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    SentryObjCMetricKitMetricReport reports = SentryObjCMetricKitMetricReportCPUCumulativeTime
        | SentryObjCMetricKitMetricReportExitBackgroundTaskTimeout;

    // -- Act --
    options.experimental.metrickit.enabledMetricReports = reports;

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.enabledMetricReports, reports);
}

- (void)testEnabledMetricReports_whenSetToNone_shouldReturnNone
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.experimental.metrickit.enabledMetricReports = SentryObjCMetricKitMetricReportAll;

    // -- Act --
    options.experimental.metrickit.enabledMetricReports = SentryObjCMetricKitMetricReportNone;

    // -- Assert --
    XCTAssertEqual(
        options.experimental.metrickit.enabledMetricReports, SentryObjCMetricKitMetricReportNone);
}

- (void)testEnabledMetricReports_whenUnknownBitsSet_shouldIgnoreThem
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.metrickit.enabledMetricReports
        = SentryObjCMetricKitMetricReportMemoryPeakUsage | (1ULL << 63);

    // -- Assert --
    XCTAssertEqual(options.experimental.metrickit.enabledMetricReports,
        SentryObjCMetricKitMetricReportMemoryPeakUsage);
}

- (void)testMetricReportConstants_shouldKeepTheirBits
{
    // The bits are public API, so a report must never move to another bit.
    XCTAssertEqual(SentryObjCMetricKitMetricReportCPUCumulativeTime, 1ULL << 0);
    XCTAssertEqual(SentryObjCMetricKitMetricReportCPUCumulativeInstructions, 1ULL << 1);
    XCTAssertEqual(SentryObjCMetricKitMetricReportGPUCumulativeTime, 1ULL << 2);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAppTimeForeground, 1ULL << 3);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAppTimeBackground, 1ULL << 4);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAppTimeBackgroundAudio, 1ULL << 5);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAppTimeBackgroundLocation, 1ULL << 6);
    XCTAssertEqual(SentryObjCMetricKitMetricReportNetworkWifiUpload, 1ULL << 7);
    XCTAssertEqual(SentryObjCMetricKitMetricReportNetworkWifiDownload, 1ULL << 8);
    XCTAssertEqual(SentryObjCMetricKitMetricReportNetworkCellularUpload, 1ULL << 9);
    XCTAssertEqual(SentryObjCMetricKitMetricReportNetworkCellularDownload, 1ULL << 10);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskIOLogicalWrites, 1ULL << 11);
    XCTAssertEqual(SentryObjCMetricKitMetricReportLocationBestAccuracyTime, 1ULL << 12);
    XCTAssertEqual(
        SentryObjCMetricKitMetricReportLocationBestAccuracyForNavigationTime, 1ULL << 13);
    XCTAssertEqual(SentryObjCMetricKitMetricReportLocationNearestTenMetersTime, 1ULL << 14);
    XCTAssertEqual(SentryObjCMetricKitMetricReportLocationHundredMetersTime, 1ULL << 15);
    XCTAssertEqual(SentryObjCMetricKitMetricReportLocationKilometerTime, 1ULL << 16);
    XCTAssertEqual(SentryObjCMetricKitMetricReportLocationThreeKilometersTime, 1ULL << 17);
    XCTAssertEqual(SentryObjCMetricKitMetricReportMemoryPeakUsage, 1ULL << 18);
    XCTAssertEqual(SentryObjCMetricKitMetricReportMemoryAverageSuspended, 1ULL << 19);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDisplayAveragePixelLuminance, 1ULL << 20);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAnimationScrollHitchTimeRatio, 1ULL << 21);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAnimationHitchTimeRatio, 1ULL << 22);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceBinaryFileSize, 1ULL << 23);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceBinaryFileCount, 1ULL << 24);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceDataFileSize, 1ULL << 25);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceDataFileCount, 1ULL << 26);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceCacheFolderSize, 1ULL << 27);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceCloneSize, 1ULL << 28);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceTotalUsed, 1ULL << 29);
    XCTAssertEqual(SentryObjCMetricKitMetricReportDiskSpaceTotalCapacity, 1ULL << 30);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitForegroundNormal, 1ULL << 31);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitForegroundMemoryResourceLimit, 1ULL << 32);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitForegroundBadAccess, 1ULL << 33);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitForegroundAbnormal, 1ULL << 34);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitForegroundIllegalInstruction, 1ULL << 35);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitForegroundWatchdog, 1ULL << 36);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundNormal, 1ULL << 37);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundMemoryResourceLimit, 1ULL << 38);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundCPUResourceLimit, 1ULL << 39);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundMemoryPressure, 1ULL << 40);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundBadAccess, 1ULL << 41);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundAbnormal, 1ULL << 42);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundIllegalInstruction, 1ULL << 43);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundWatchdog, 1ULL << 44);
    XCTAssertEqual(
        SentryObjCMetricKitMetricReportExitBackgroundSuspendedWithLockedFile, 1ULL << 45);
    XCTAssertEqual(SentryObjCMetricKitMetricReportExitBackgroundTaskTimeout, 1ULL << 46);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAnimationTotalHitchTime, 1ULL << 47);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAnimationTotalAnimationTime, 1ULL << 48);
    XCTAssertEqual(SentryObjCMetricKitMetricReportMetalFramesPerSecond, 1ULL << 49);
    XCTAssertEqual(SentryObjCMetricKitMetricReportMetalFrameCount, 1ULL << 50);
    XCTAssertEqual(SentryObjCMetricKitMetricReportMetalActiveDrawingDuration, 1ULL << 51);
    XCTAssertEqual(SentryObjCMetricKitMetricReportNone, 0ULL);
    XCTAssertEqual(SentryObjCMetricKitMetricReportAll, (1ULL << 52) - 1);
}

@end

#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
