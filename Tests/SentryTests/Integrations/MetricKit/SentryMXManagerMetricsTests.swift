#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import SentryTestUtils
import XCTest

#if os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))

import MetricKit

final class SentryMXManagerMetricsTests: XCTestCase {

    private let timeStampBegin = Date(timeIntervalSince1970: 1_800_000_000)
    private let timeStampEnd = Date(timeIntervalSince1970: 1_800_086_400)
    private let bundleInfo: [String: Any] = [
        "CFBundleIdentifier": "io.sentry.app",
        "CFBundleShortVersionString": "2.0.0",
        "CFBundleVersion": "20"
    ]

    // MARK: - Enabled Reports

    func testDidReceive_whenNoMetricReportsEnabled_shouldNotRecordMetrics() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [], metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        XCTAssertTrue(metricsApi.recordedMetrics.isEmpty)
    }

    func testDidReceive_whenOnlySomeReportsEnabled_shouldRecordOnlyThose() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime, .exitForegroundWatchdog], metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.map(\.key), [
            "metrickit.cpu.cumulative_time",
            "metrickit.exit.fg.watchdog"
        ])
    }

    func testDidReceive_whenAllReportsEnabled_shouldRecordEveryReportOfThePayload() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: .all, metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        var expectedReports = Set<SentryMetricKit.MetricReport>.all
        // The fixture reports no normal exits, and a count of zero is left out.
        expectedReports.subtract([.exitForegroundNormal, .exitBackgroundNormal])
        if !Self.supportsIOS26Metrics {
            expectedReports.subtract(Self.iOS26Reports)
        }
        XCTAssertEqual(Set(metricsApi.recordedMetrics.map(\.key)), Set(expectedReports.map(\.name)))
        XCTAssertEqual(metricsApi.recordedMetrics.count, expectedReports.count)
    }

    func testDidReceive_whenMultiplePayloads_shouldRecordEachPayload() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload(), givenPayload()])

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.count, 2)
    }

    // MARK: - Metric Groups

    func testDidReceive_whenCPUReportsEnabled_shouldRecordCPUMetrics() {
        assertRecordedMetrics(for: [.cpuCumulativeTime, .cpuCumulativeInstructions], [
            .init(key: "metrickit.cpu.cumulative_time", kind: .distribution, value: 120, unit: .second),
            .init(key: "metrickit.cpu.cumulative_instructions", kind: .distribution, value: 5_000, unit: nil)
        ])
    }

    func testDidReceive_whenGPUReportsEnabled_shouldRecordGPUMetrics() {
        assertRecordedMetrics(for: [.gpuCumulativeTime], [
            .init(key: "metrickit.gpu.cumulative_time", kind: .distribution, value: 1.5, unit: .second)
        ])
    }

    func testDidReceive_whenAppTimeReportsEnabled_shouldRecordAppTimeMetrics() {
        assertRecordedMetrics(for: [.appTimeForeground, .appTimeBackground, .appTimeBackgroundAudio, .appTimeBackgroundLocation], [
            .init(key: "metrickit.app_time.foreground", kind: .distribution, value: 3_600, unit: .second),
            .init(key: "metrickit.app_time.background", kind: .distribution, value: 600, unit: .second),
            .init(key: "metrickit.app_time.background_audio", kind: .distribution, value: 30, unit: .second),
            .init(key: "metrickit.app_time.background_location", kind: .distribution, value: 0, unit: .second)
        ])
    }

    func testDidReceive_whenNetworkReportsEnabled_shouldRecordNetworkMetrics() {
        assertRecordedMetrics(for: [.networkWifiUpload, .networkWifiDownload, .networkCellularUpload, .networkCellularDownload], [
            .init(key: "metrickit.network.wifi_upload", kind: .distribution, value: 1_000, unit: .byte),
            .init(key: "metrickit.network.wifi_download", kind: .distribution, value: 2_000_000, unit: .byte),
            .init(key: "metrickit.network.cellular_upload", kind: .distribution, value: 3_000, unit: .byte),
            .init(key: "metrickit.network.cellular_download", kind: .distribution, value: 4_000_000, unit: .byte)
        ])
    }

    func testDidReceive_whenDiskIOReportsEnabled_shouldRecordDiskIOMetrics() {
        assertRecordedMetrics(for: [.diskIOLogicalWrites], [
            .init(key: "metrickit.disk_io.logical_writes", kind: .distribution, value: 2_048, unit: .byte)
        ])
    }

    func testDidReceive_whenLocationReportsEnabled_shouldRecordLocationMetrics() {
        assertRecordedMetrics(for: [
            .locationBestAccuracyTime,
            .locationBestAccuracyForNavigationTime,
            .locationNearestTenMetersTime,
            .locationHundredMetersTime,
            .locationKilometerTime,
            .locationThreeKilometersTime
        ], [
            .init(key: "metrickit.location.best_accuracy_time", kind: .distribution, value: 1, unit: .second),
            .init(key: "metrickit.location.best_accuracy_for_nav_time", kind: .distribution, value: 2, unit: .second),
            .init(key: "metrickit.location.nearest_ten_meters_time", kind: .distribution, value: 3, unit: .second),
            .init(key: "metrickit.location.hundred_meters_time", kind: .distribution, value: 4, unit: .second),
            .init(key: "metrickit.location.kilometer_time", kind: .distribution, value: 5, unit: .second),
            .init(key: "metrickit.location.three_kilometers_time", kind: .distribution, value: 360, unit: .second)
        ])
    }

    func testDidReceive_whenMemoryReportsEnabled_shouldRecordMemoryMetrics() {
        assertRecordedMetrics(for: [.memoryPeakUsage, .memoryAverageSuspended], [
            .init(key: "metrickit.memory.peak_usage", kind: .gauge, value: 300_000_000, unit: .byte),
            .init(key: "metrickit.memory.avg_suspended", kind: .gauge, value: 50_000_000, unit: .byte)
        ])
    }

    func testDidReceive_whenDisplayReportsEnabled_shouldRecordDisplayMetrics() {
        assertRecordedMetrics(for: [.displayAveragePixelLuminance], [
            .init(key: "metrickit.display.avg_pixel_luminance", kind: .gauge, value: 42, unit: .generic("apl"))
        ])
    }

    func testDidReceive_whenAnimationReportsEnabled_shouldRecordAnimationMetricsAsRatio() {
        var expected: [ExpectedMetric] = [
            .init(key: "metrickit.animation.scroll_hitch_time_ratio", kind: .gauge, value: 0.005, unit: .ratio)
        ]
        if Self.supportsIOS26Metrics {
            expected.append(.init(key: "metrickit.animation.hitch_time_ratio", kind: .gauge, value: 0.012, unit: .ratio))
        }
        assertRecordedMetrics(for: [.animationScrollHitchTimeRatio, .animationHitchTimeRatio], expected)
    }

    func testDidReceive_whenDiskSpaceReportsEnabled_shouldRecordDiskSpaceMetrics() throws {
        guard Self.supportsIOS26Metrics else {
            throw XCTSkip("Disk space usage metrics require iOS 26 or macOS 26 and Xcode 26")
        }
        assertRecordedMetrics(for: Self.iOS26Reports.subtracting([.animationHitchTimeRatio]), [
            .init(key: "metrickit.disk_space.binary_file_size", kind: .gauge, value: 10_000_000, unit: .byte),
            .init(key: "metrickit.disk_space.binary_file_count", kind: .gauge, value: 12, unit: nil),
            .init(key: "metrickit.disk_space.data_file_size", kind: .gauge, value: 20_000_000, unit: .byte),
            .init(key: "metrickit.disk_space.data_file_count", kind: .gauge, value: 340, unit: nil),
            .init(key: "metrickit.disk_space.cache_folder_size", kind: .gauge, value: 5_000_000, unit: .byte),
            .init(key: "metrickit.disk_space.clone_size", kind: .gauge, value: 1_000_000, unit: .byte),
            .init(key: "metrickit.disk_space.total_used", kind: .gauge, value: 36_000_000, unit: .byte),
            .init(key: "metrickit.disk_space.total_capacity", kind: .gauge, value: 128_000_000_000, unit: .byte)
        ])
    }

    func testDidReceive_whenForegroundExitReportsEnabled_shouldRecordNonZeroForegroundExitCounts() {
        assertRecordedMetrics(for: [
            .exitForegroundNormal,
            .exitForegroundMemoryResourceLimit,
            .exitForegroundBadAccess,
            .exitForegroundAbnormal,
            .exitForegroundIllegalInstruction,
            .exitForegroundWatchdog
        ], [
            .init(key: "metrickit.exit.fg.memory_resource_limit", kind: .count, value: 1, unit: nil),
            .init(key: "metrickit.exit.fg.bad_access", kind: .count, value: 2, unit: nil),
            .init(key: "metrickit.exit.fg.abnormal", kind: .count, value: 3, unit: nil),
            .init(key: "metrickit.exit.fg.illegal_instruction", kind: .count, value: 4, unit: nil),
            .init(key: "metrickit.exit.fg.watchdog", kind: .count, value: 5, unit: nil)
        ])
    }

    func testDidReceive_whenBackgroundExitReportsEnabled_shouldRecordNonZeroBackgroundExitCounts() {
        assertRecordedMetrics(for: [
            .exitBackgroundNormal,
            .exitBackgroundMemoryResourceLimit,
            .exitBackgroundCPUResourceLimit,
            .exitBackgroundMemoryPressure,
            .exitBackgroundBadAccess,
            .exitBackgroundAbnormal,
            .exitBackgroundIllegalInstruction,
            .exitBackgroundWatchdog,
            .exitBackgroundSuspendedWithLockedFile,
            .exitBackgroundTaskTimeout
        ], [
            .init(key: "metrickit.exit.bg.memory_resource_limit", kind: .count, value: 11, unit: nil),
            .init(key: "metrickit.exit.bg.cpu_resource_limit", kind: .count, value: 12, unit: nil),
            .init(key: "metrickit.exit.bg.memory_pressure", kind: .count, value: 13, unit: nil),
            .init(key: "metrickit.exit.bg.bad_access", kind: .count, value: 14, unit: nil),
            .init(key: "metrickit.exit.bg.abnormal", kind: .count, value: 15, unit: nil),
            .init(key: "metrickit.exit.bg.illegal_instruction", kind: .count, value: 16, unit: nil),
            .init(key: "metrickit.exit.bg.watchdog", kind: .count, value: 17, unit: nil),
            .init(key: "metrickit.exit.bg.suspended_with_locked_file", kind: .count, value: 18, unit: nil),
            .init(key: "metrickit.exit.bg.background_task_timeout", kind: .count, value: 19, unit: nil)
        ])
    }

    func testDidReceive_whenMetricGroupIsMissing_shouldSkipItsReports() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: .all, metricsApi: metricsApi)
        let payload = TestMXMetricPayload()

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        XCTAssertTrue(metricsApi.recordedMetrics.isEmpty)
    }

    // MARK: - Units

    func testDidReceive_whenCPUInstructionsUseUnexpectedUnit_shouldSkipOnlyThatMetric() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime, .cpuCumulativeInstructions], metricsApi: metricsApi)
        let payload = givenPayload()
        let cpu = TestMXCPUMetric()
        cpu.overrides.cumulativeCPUInstructions = Measurement(value: 5, unit: Unit(symbol: "megainstructions"))
        payload.overrides.cpuMetrics = cpu

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.map(\.key), ["metrickit.cpu.cumulative_time"])
    }

    func testDidReceive_whenCPUInstructionsAreInInstructions_shouldKeepValue() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeInstructions], metricsApi: metricsApi)
        let payload = givenPayload()
        let cpu = TestMXCPUMetric()
        cpu.overrides.cumulativeCPUInstructions = Measurement(value: 750, unit: Unit(symbol: "instructions"))
        payload.overrides.cpuMetrics = cpu

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(metricsApi.recordedMetrics.first).value, 750)
    }

    func testDidReceive_whenHitchTimeRatioUsesUnexpectedUnit_shouldSkipMetric() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.animationScrollHitchTimeRatio], metricsApi: metricsApi)
        let payload = givenPayload()
        let animation = TestMXAnimationMetric()
        animation.overrides.scrollHitchTimeRatio = Measurement(value: 5, unit: Unit(symbol: "%"))
        payload.overrides.animationMetrics = animation

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        XCTAssertTrue(metricsApi.recordedMetrics.isEmpty)
    }

    // MARK: - Timestamp

    func testDidReceive_shouldStampMetricsWithMiddleOfReportingInterval() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime, .memoryPeakUsage, .exitForegroundWatchdog], metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.count, 3)
        for metric in metricsApi.recordedMetrics {
            XCTAssertEqual(metric.timestamp, Date(timeIntervalSince1970: 1_800_043_200), "Unexpected timestamp for \(metric.key)")
        }
    }

    // MARK: - Attributes

    func testDidReceive_whenPayloadIsFromPreviousAppVersion_shouldDescribeRecordedReleaseAndOSVersion() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertEqual(metric.attributes, [
            "app.version": .string("1.0.0"),
            "app.build": .string("10"),
            "sentry.release": .string("io.sentry.app@1.0.0+10"),
            "os.version": .string("18.6.2")
        ])
    }

    func testDidReceive_whenPayloadIsFromRunningAppVersion_shouldNotSetRelease() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        let payload = givenPayload()
        payload.overrides.latestApplicationVersion = "2.0.0"
        payload.overrides.metaData?.overrides.applicationBuildVersion = "20"

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertEqual(metric.attributes, [
            "app.version": .string("2.0.0"),
            "app.build": .string("20"),
            "os.version": .string("18.6.2")
        ])
    }

    func testDidReceive_whenReleaseNameIsCustom_shouldNotSetRelease() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi, releaseName: "custom-release")

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertEqual(metric.attributes["app.version"], .string("1.0.0"))
        XCTAssertNil(metric.attributes["sentry.release"])
    }

    func testDidReceive_whenPayloadSpansMultipleAppVersions_shouldNotDescribeAppVersion() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        let payload = givenPayload()
        payload.overrides.includesMultipleApplicationVersions = true

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertEqual(metric.attributes, ["os.version": .string("18.6.2")])
    }

    func testDidReceive_whenMetaDataIsMissing_shouldOnlyDescribeAppVersion() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        let payload = givenPayload()
        payload.overrides.metaData = nil

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        // Without a build, the previous release can't be reconstructed.
        XCTAssertEqual(metric.attributes, ["app.version": .string("1.0.0")])
    }

    func testDidReceive_whenOSVersionCantBeParsed_shouldNotSetOSVersion() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        let payload = givenPayload()
        payload.overrides.metaData?.overrides.osVersion = "unknown"

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertNil(metric.attributes["os.version"])
    }

    func testDidReceive_shouldUseOneNewTraceIdPerPayload() throws {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime, .gpuCumulativeTime], metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload(), givenPayload()])

        // -- Assert --
        let traceIds = metricsApi.recordedMetrics.map(\.traceId)
        XCTAssertEqual(traceIds.count, 4)
        XCTAssertEqual(traceIds[0], traceIds[1], "Metrics of one payload should share a trace")
        XCTAssertEqual(traceIds[2], traceIds[3], "Metrics of one payload should share a trace")
        XCTAssertNotEqual(traceIds[0], traceIds[2], "Each payload should get its own trace")
    }

    // MARK: - Helpers

    private static var supportsIOS26Metrics: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return true
        }
        #endif // compiler(>=6.2)
        return false
    }

    private static let iOS26Reports: Set<SentryMetricKit.MetricReport> = [
        .animationHitchTimeRatio,
        .diskSpaceBinaryFileSize,
        .diskSpaceBinaryFileCount,
        .diskSpaceDataFileSize,
        .diskSpaceDataFileCount,
        .diskSpaceCacheFolderSize,
        .diskSpaceCloneSize,
        .diskSpaceTotalUsed,
        .diskSpaceTotalCapacity
    ]

    private func givenSut(
        enabledMetricReports: Set<SentryMetricKit.MetricReport>,
        metricsApi: TestInternalMetricsApi,
        releaseName: String = "io.sentry.app@2.0.0+20"
    ) -> SentryMXManager {
        SentryMXManager(
            diagnosticCapturer: SentryMXDiagnosticCapturer(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                attachDiagnosticAsAttachment: false,
                enabledDiagnostics: [],
                processStartDate: .distantPast
            ),
            enabledMetricReports: enabledMetricReports,
            metricsApi: metricsApi,
            releaseName: releaseName,
            bundleInfo: bundleInfo
        )
    }

    private func givenPayload() -> TestMXMetricPayload {
        let payload = TestMXMetricPayload()
        payload.overrides.timeStampBegin = timeStampBegin
        payload.overrides.timeStampEnd = timeStampEnd
        payload.overrides.latestApplicationVersion = "1.0.0"

        let metaData = TestMXMetaData()
        metaData.overrides.osVersion = "iPhone OS 18.6.2 (22G100)"
        metaData.overrides.applicationBuildVersion = "10"
        payload.overrides.metaData = metaData

        payload.overrides.cpuMetrics = TestMXCPUMetric()
        payload.overrides.gpuMetrics = TestMXGPUMetric()
        payload.overrides.applicationTimeMetrics = TestMXAppRunTimeMetric()
        payload.overrides.networkTransferMetrics = TestMXNetworkTransferMetric()
        payload.overrides.diskIOMetrics = TestMXDiskIOMetric()
        payload.overrides.locationActivityMetrics = TestMXLocationActivityMetric()
        payload.overrides.memoryMetrics = TestMXMemoryMetric()
        payload.overrides.displayMetrics = TestMXDisplayMetric()
        payload.overrides.animationMetrics = TestMXAnimationMetric()
        payload.overrides.applicationExitMetrics = TestMXAppExitMetric()
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            payload.overrides.diskSpaceUsageMetrics = TestMXDiskSpaceUsageMetric()
        }
        #endif // compiler(>=6.2)
        return payload
    }

    private func assertRecordedMetrics(
        for reports: Set<SentryMetricKit.MetricReport>,
        _ expected: [ExpectedMetric],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: reports, metricsApi: metricsApi)

        // -- Act --
        sut.didReceive([givenPayload()])

        // -- Assert --
        let recorded = metricsApi.recordedMetrics
        XCTAssertEqual(recorded.map(\.key), expected.map(\.key), file: file, line: line)
        for (metric, expectedMetric) in zip(recorded, expected) {
            XCTAssertEqual(metric.kind, expectedMetric.kind, "Unexpected kind for \(metric.key)", file: file, line: line)
            XCTAssertEqual(metric.value, expectedMetric.value, accuracy: 0.000001, "Unexpected value for \(metric.key)", file: file, line: line)
            XCTAssertEqual(metric.unit, expectedMetric.unit, "Unexpected unit for \(metric.key)", file: file, line: line)
        }
    }
}

// MARK: - Test Doubles

private struct ExpectedMetric {
    let key: String
    let kind: TestInternalMetricsApi.Kind
    let value: Double
    let unit: SentryUnit?
}

private final class TestInternalMetricsApi: SentryInternalMetricsApi {
    enum Kind {
        case count
        case distribution
        case gauge
    }

    struct RecordedMetric {
        let kind: Kind
        let key: String
        let value: Double
        let unit: SentryUnit?
        let timestamp: Date
        let traceId: SentryId
        let attributes: [String: SentryAttributeContent]
    }

    private let invocations = Invocations<RecordedMetric>()

    var recordedMetrics: [RecordedMetric] {
        invocations.invocations
    }

    func count(key: String, value: UInt, timestamp: Date, traceId: SentryId, attributes: [String: SentryAttributeValue]) {
        record(.count, key: key, value: Double(value), unit: nil, timestamp: timestamp, traceId: traceId, attributes: attributes)
    }

    func distribution(key: String, value: Double, unit: SentryUnit?, timestamp: Date, traceId: SentryId, attributes: [String: SentryAttributeValue]) {
        record(.distribution, key: key, value: value, unit: unit, timestamp: timestamp, traceId: traceId, attributes: attributes)
    }

    func gauge(key: String, value: Double, unit: SentryUnit?, timestamp: Date, traceId: SentryId, attributes: [String: SentryAttributeValue]) {
        record(.gauge, key: key, value: value, unit: unit, timestamp: timestamp, traceId: traceId, attributes: attributes)
    }

    private func record(
        _ kind: Kind,
        key: String,
        value: Double,
        unit: SentryUnit?,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue]
    ) {
        invocations.record(RecordedMetric(
            kind: kind,
            key: key,
            value: value,
            unit: unit,
            timestamp: timestamp,
            traceId: traceId,
            attributes: attributes.mapValues(\.asSentryAttributeContent)
        ))
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXMetricPayload: MXMetricPayload {
    struct Override {
        var timeStampBegin = Date(timeIntervalSince1970: 0)
        var timeStampEnd = Date(timeIntervalSince1970: 0)
        var latestApplicationVersion = ""
        var includesMultipleApplicationVersions = false
        var metaData: TestMXMetaData?
        var cpuMetrics: MXCPUMetric?
        var gpuMetrics: MXGPUMetric?
        var applicationTimeMetrics: MXAppRunTimeMetric?
        var networkTransferMetrics: MXNetworkTransferMetric?
        var diskIOMetrics: MXDiskIOMetric?
        var locationActivityMetrics: MXLocationActivityMetric?
        var memoryMetrics: MXMemoryMetric?
        var displayMetrics: MXDisplayMetric?
        var animationMetrics: MXAnimationMetric?
        var applicationExitMetrics: MXAppExitMetric?
        // Typed as MXMetric because MXDiskSpaceUsageMetric requires iOS 26.
        var diskSpaceUsageMetrics: MXMetric?
    }

    var overrides = Override()

    override var timeStampBegin: Date { overrides.timeStampBegin }
    override var timeStampEnd: Date { overrides.timeStampEnd }
    override var latestApplicationVersion: String { overrides.latestApplicationVersion }
    override var includesMultipleApplicationVersions: Bool { overrides.includesMultipleApplicationVersions }
    override var metaData: MXMetaData? { overrides.metaData }
    override var cpuMetrics: MXCPUMetric? { overrides.cpuMetrics }
    override var gpuMetrics: MXGPUMetric? { overrides.gpuMetrics }
    override var applicationTimeMetrics: MXAppRunTimeMetric? { overrides.applicationTimeMetrics }
    override var networkTransferMetrics: MXNetworkTransferMetric? { overrides.networkTransferMetrics }
    override var diskIOMetrics: MXDiskIOMetric? { overrides.diskIOMetrics }
    override var locationActivityMetrics: MXLocationActivityMetric? { overrides.locationActivityMetrics }
    override var memoryMetrics: MXMemoryMetric? { overrides.memoryMetrics }
    override var displayMetrics: MXDisplayMetric? { overrides.displayMetrics }
    override var animationMetrics: MXAnimationMetric? { overrides.animationMetrics }
    override var applicationExitMetrics: MXAppExitMetric? { overrides.applicationExitMetrics }

    #if compiler(>=6.2)
    @available(iOS 26.0, macOS 26.0, *)
    override var diskSpaceUsageMetrics: MXDiskSpaceUsageMetric? {
        overrides.diskSpaceUsageMetrics as? MXDiskSpaceUsageMetric
    }
    #endif // compiler(>=6.2)
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCPUMetric: MXCPUMetric {
    struct Override {
        var cumulativeCPUTime = Measurement(value: 2, unit: UnitDuration.minutes)
        var cumulativeCPUInstructions = Measurement(value: 5, unit: Unit(symbol: "kiloinstructions"))
    }

    var overrides = Override()

    override var cumulativeCPUTime: Measurement<UnitDuration> { overrides.cumulativeCPUTime }
    override var cumulativeCPUInstructions: Measurement<Unit> { overrides.cumulativeCPUInstructions }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXGPUMetric: MXGPUMetric {
    override var cumulativeGPUTime: Measurement<UnitDuration> { Measurement(value: 1_500, unit: .milliseconds) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXAppRunTimeMetric: MXAppRunTimeMetric {
    override var cumulativeForegroundTime: Measurement<UnitDuration> { Measurement(value: 1, unit: .hours) }
    override var cumulativeBackgroundTime: Measurement<UnitDuration> { Measurement(value: 10, unit: .minutes) }
    override var cumulativeBackgroundAudioTime: Measurement<UnitDuration> { Measurement(value: 30, unit: .seconds) }
    override var cumulativeBackgroundLocationTime: Measurement<UnitDuration> { Measurement(value: 0, unit: .seconds) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXNetworkTransferMetric: MXNetworkTransferMetric {
    override var cumulativeWifiUpload: Measurement<UnitInformationStorage> { Measurement(value: 1, unit: .kilobytes) }
    override var cumulativeWifiDownload: Measurement<UnitInformationStorage> { Measurement(value: 2, unit: .megabytes) }
    override var cumulativeCellularUpload: Measurement<UnitInformationStorage> { Measurement(value: 3, unit: .kilobytes) }
    override var cumulativeCellularDownload: Measurement<UnitInformationStorage> { Measurement(value: 4, unit: .megabytes) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDiskIOMetric: MXDiskIOMetric {
    override var cumulativeLogicalWrites: Measurement<UnitInformationStorage> { Measurement(value: 2, unit: .kibibytes) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXLocationActivityMetric: MXLocationActivityMetric {
    override var cumulativeBestAccuracyTime: Measurement<UnitDuration> { Measurement(value: 1, unit: .seconds) }
    override var cumulativeBestAccuracyForNavigationTime: Measurement<UnitDuration> { Measurement(value: 2, unit: .seconds) }
    override var cumulativeNearestTenMetersAccuracyTime: Measurement<UnitDuration> { Measurement(value: 3, unit: .seconds) }
    override var cumulativeHundredMetersAccuracyTime: Measurement<UnitDuration> { Measurement(value: 4, unit: .seconds) }
    override var cumulativeKilometerAccuracyTime: Measurement<UnitDuration> { Measurement(value: 5_000, unit: .milliseconds) }
    override var cumulativeThreeKilometersAccuracyTime: Measurement<UnitDuration> { Measurement(value: 6, unit: .minutes) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXStorageAverage: MXAverage<UnitInformationStorage> {
    override var averageMeasurement: Measurement<UnitInformationStorage> { Measurement(value: 50, unit: .megabytes) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXMemoryMetric: MXMemoryMetric {
    override var peakMemoryUsage: Measurement<UnitInformationStorage> { Measurement(value: 300, unit: .megabytes) }
    override var averageSuspendedMemory: MXAverage<UnitInformationStorage> { TestMXStorageAverage() }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXLuminanceAverage: MXAverage<MXUnitAveragePixelLuminance> {
    override var averageMeasurement: Measurement<MXUnitAveragePixelLuminance> { Measurement(value: 42, unit: .apl) }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDisplayMetric: MXDisplayMetric {
    override var averagePixelLuminance: MXAverage<MXUnitAveragePixelLuminance>? { TestMXLuminanceAverage() }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXAnimationMetric: MXAnimationMetric {
    struct Override {
        var scrollHitchTimeRatio = Measurement(value: 5, unit: Unit(symbol: "ms per s"))
        var hitchTimeRatio = Measurement(value: 12, unit: Unit(symbol: "ms per s"))
    }

    var overrides = Override()

    override var scrollHitchTimeRatio: Measurement<Unit> { overrides.scrollHitchTimeRatio }

    #if compiler(>=6.2)
    @available(iOS 26.0, macOS 26.0, *)
    override var hitchTimeRatio: Measurement<Unit> { overrides.hitchTimeRatio }
    #endif // compiler(>=6.2)
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXForegroundExitData: MXForegroundExitData {
    override var cumulativeNormalAppExitCount: Int { 0 }
    override var cumulativeMemoryResourceLimitExitCount: Int { 1 }
    override var cumulativeBadAccessExitCount: Int { 2 }
    override var cumulativeAbnormalExitCount: Int { 3 }
    override var cumulativeIllegalInstructionExitCount: Int { 4 }
    override var cumulativeAppWatchdogExitCount: Int { 5 }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXBackgroundExitData: MXBackgroundExitData {
    override var cumulativeNormalAppExitCount: Int { 0 }
    override var cumulativeMemoryResourceLimitExitCount: Int { 11 }
    override var cumulativeCPUResourceLimitExitCount: Int { 12 }
    override var cumulativeMemoryPressureExitCount: Int { 13 }
    override var cumulativeBadAccessExitCount: Int { 14 }
    override var cumulativeAbnormalExitCount: Int { 15 }
    override var cumulativeIllegalInstructionExitCount: Int { 16 }
    override var cumulativeAppWatchdogExitCount: Int { 17 }
    override var cumulativeSuspendedWithLockedFileExitCount: Int { 18 }
    override var cumulativeBackgroundTaskAssertionTimeoutExitCount: Int { 19 }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXAppExitMetric: MXAppExitMetric {
    override var foregroundExitData: MXForegroundExitData { TestMXForegroundExitData() }
    override var backgroundExitData: MXBackgroundExitData { TestMXBackgroundExitData() }
}

#if compiler(>=6.2)
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDiskSpaceUsageMetric: MXDiskSpaceUsageMetric {
    override var totalBinaryFileSize: Measurement<UnitInformationStorage> { Measurement(value: 10, unit: .megabytes) }
    override var totalBinaryFileCount: Int { 12 }
    override var totalDataFileSize: Measurement<UnitInformationStorage> { Measurement(value: 20, unit: .megabytes) }
    override var totalDataFileCount: Int { 340 }
    override var totalCacheFolderSize: Measurement<UnitInformationStorage> { Measurement(value: 5, unit: .megabytes) }
    override var totalCloneSize: Measurement<UnitInformationStorage> { Measurement(value: 1, unit: .megabytes) }
    override var totalDiskSpaceUsedSize: Measurement<UnitInformationStorage> { Measurement(value: 36, unit: .megabytes) }
    override var totalDiskSpaceCapacity: Measurement<UnitInformationStorage> { Measurement(value: 128, unit: .gigabytes) }
}
#endif // compiler(>=6.2)

#endif // os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))
