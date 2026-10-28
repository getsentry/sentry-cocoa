#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import SentryTestUtils
import XCTest

#if (os(iOS) || os(macOS)) && compiler(>=6.4)
import MetricKit

final class SentryMetricManagerMetricReportsTests: XCTestCase {

    private let timeStampBegin = Date(timeIntervalSince1970: 1_800_000_000)
    private let timeStampEnd = Date(timeIntervalSince1970: 1_800_086_400)
    private let bundleInfo: [String: Any] = [
        "CFBundleIdentifier": "io.sentry.app",
        "CFBundleShortVersionString": "2.0.0",
        "CFBundleVersion": "20"
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("MetricManager reports metrics from iOS 27 and macOS 27")
        }
    }

    // MARK: - Same metrics as legacy payloads

    func testProcess_whenReportHasLegacyPayloadValues_shouldRecordSameMetricsAsLegacyPayload() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let legacyMetricsApi = TestInternalMetricsApi()
        let metricsApi = TestInternalMetricsApi()
        let reports = Self.reportsOfBothAPIs
        let legacySut = SentryMXManager(metricManager: TestMXMetricManager(), metricRecorder: givenMetricRecorder(enabledMetricReports: reports, metricsApi: legacyMetricsApi))
        let sut = givenSut(enabledMetricReports: reports, metricsApi: metricsApi)
        let report = try givenReport(values: legacyPayloadValues())

        // -- Act --
        legacySut.didReceive([givenLegacyPayload()])
        sut.process(metricReport: report)

        // -- Assert --
        let legacyMetrics = legacyMetricsApi.recordedMetrics.sorted { $0.key < $1.key }
        let metrics = metricsApi.recordedMetrics.sorted { $0.key < $1.key }
        // The fixture reports no normal exits, and a count of zero is left out.
        XCTAssertEqual(Set(metrics.map(\.key)), Set(reports.subtracting([.exitForegroundNormal, .exitBackgroundNormal]).map(\.name)))
        XCTAssertEqual(metrics.map(\.key), legacyMetrics.map(\.key))
        for (metric, legacyMetric) in zip(metrics, legacyMetrics) {
            XCTAssertEqual(metric.kind, legacyMetric.kind, "Unexpected kind for \(metric.key)")
            XCTAssertEqual(metric.value, legacyMetric.value, accuracy: 0.000001, "Unexpected value for \(metric.key)")
            XCTAssertEqual(metric.unit, legacyMetric.unit, "Unexpected unit for \(metric.key)")
            XCTAssertEqual(metric.timestamp, legacyMetric.timestamp, "Unexpected timestamp for \(metric.key)")
            XCTAssertEqual(metric.attributes, legacyMetric.attributes, "Unexpected attributes for \(metric.key)")
        }
    }

    // MARK: - Metrics only MetricManager reports

    func testProcess_whenHitchTimeReported_shouldRecordHitchAndAnimationTime() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.animationTotalHitchTime, .animationTotalAnimationTime], metricsApi: metricsApi)
        let report = try givenReport(values: [
            ["hitchTimeMetric": [
                "ratio": ["value": 12, "unit": "ms per s"],
                "totalHitchTime": seconds(Measurement(value: 1_500, unit: .milliseconds)),
                "totalAnimationTime": seconds(Measurement(value: 2, unit: .minutes))
            ]]
        ])

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        let metrics = metricsApi.recordedMetrics
        XCTAssertEqual(metrics.map(\.key), ["metrickit.animation.total_hitch_time", "metrickit.animation.total_animation_time"])
        XCTAssertEqual(metrics.map(\.kind), [.distribution, .distribution])
        XCTAssertEqual(metrics.map(\.value), [1.5, 120])
        XCTAssertEqual(metrics.map(\.unit), [.second, .second])
    }

    func testProcess_whenMetalFrameRatesReported_shouldRecordEachLayerWithItsName() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.metalFramesPerSecond, .metalFrameCount, .metalActiveDrawingDuration], metricsApi: metricsApi)
        let report = try givenReport(values: [
            metalFrameRate(layerName: "game", framesPerSecond: 60, frameCount: 3_600, activeDrawingSeconds: 60),
            metalFrameRate(layerName: "map", framesPerSecond: 30, frameCount: 300, activeDrawingSeconds: 10)
        ])

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        let metrics = metricsApi.recordedMetrics
        XCTAssertEqual(metrics.map(\.key), [
            "metrickit.metal.frames_per_second", "metrickit.metal.frame_count", "metrickit.metal.active_drawing_duration",
            "metrickit.metal.frames_per_second", "metrickit.metal.frame_count", "metrickit.metal.active_drawing_duration"
        ])
        XCTAssertEqual(metrics.map(\.kind), [.gauge, .count, .distribution, .gauge, .count, .distribution])
        XCTAssertEqual(metrics.map(\.value), [60, 3_600, 60, 30, 300, 10])
        XCTAssertEqual(metrics.map(\.unit), [.generic("fps"), nil, .second, .generic("fps"), nil, .second])
        XCTAssertEqual(metrics.map { $0.attributes["metal.layer_name"] }, [
            .string("game"), .string("game"), .string("game"), .string("map"), .string("map"), .string("map")
        ])
        // The layer name comes on top of the report's attributes.
        XCTAssertEqual(metrics.first?.attributes["app.version"], .string("1.0.0"))
    }

    // MARK: - Enabled reports

    func testProcess_whenOnlySomeReportsEnabled_shouldRecordOnlyThose() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime, .exitBackgroundWatchdog], metricsApi: metricsApi)
        let report = try givenReport(values: legacyPayloadValues())

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.map(\.key), ["metrickit.cpu.cumulative_time", "metrickit.exit.bg.watchdog"])
    }

    func testProcess_whenReportHasNoIntervalEntries_shouldNotRecordMetrics() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: .all, metricsApi: metricsApi)
        let report = try givenReport(intervalEntries: [])

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        XCTAssertTrue(metricsApi.recordedMetrics.isEmpty)
    }

    func testProcess_whenReportHasStateEntries_shouldRecordFullDayEntryOnly() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        let state: [String: Any] = ["domain": "app", "label": "playing", "duration": seconds(Measurement(value: 10, unit: .seconds)), "stableMetadata": [String: Any]()]
        let report = try givenReport(intervalEntries: [
            intervalEntry(states: [state], duration: Measurement(value: 10, unit: .seconds), values: [["cpuTimeMetric": ["value": seconds(Measurement(value: 1, unit: .seconds))]]]),
            intervalEntry(values: [["cpuTimeMetric": ["value": seconds(Measurement(value: 9, unit: .seconds))]]])
        ])

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.map(\.value), [9])
    }

    // MARK: - Attributes

    func testProcess_whenEnvironmentIsMissing_shouldKeepRunningVersions() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        let report = try givenReport(values: legacyPayloadValues(), environment: nil)

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertEqual(metric.timestamp, Date(timeIntervalSince1970: 1_800_043_200))
        XCTAssertEqual(metric.attributes, [:])
    }

    func testProcess_whenReportSpansMultipleAppVersions_shouldNotDescribeAppVersion() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        var environment = Self.givenEnvironment()
        environment["includesMultipleApplicationVersions"] = true
        let report = try givenReport(values: legacyPayloadValues(), environment: environment)

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertEqual(metric.attributes, ["os.version": .string("18.6.2")])
    }

    func testProcess_whenOSVersionIsEmpty_shouldNotOverrideOSVersion() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi)
        var environment = Self.givenEnvironment()
        environment["osVersion"] = ["platform": "", "number": "", "buildNumber": ""]
        let report = try givenReport(values: legacyPayloadValues(), environment: environment)

        // -- Act --
        sut.process(metricReport: report)

        // -- Assert --
        let metric = try XCTUnwrap(metricsApi.recordedMetrics.first)
        XCTAssertNil(metric.attributes["os.version"])
        XCTAssertEqual(metric.attributes["sentry.release"], .string("io.sentry.app@1.0.0+10"))
    }

    // MARK: - Receiving reports

    func testReceiveReports_shouldRecordMetricsFromMetricManager() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let source = TestMetricReportSource()
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: metricsApi, source: source)
        let recorded = expectation(for: NSPredicate { _, _ in metricsApi.recordedMetrics.count == 1 }, evaluatedWith: nil)

        // -- Act --
        sut.receiveReports()
        source.continuation.yield(try givenReport(values: legacyPayloadValues()))

        // -- Assert --
        wait(for: [recorded], timeout: 5)
    }

    func testPauseReports_shouldStopIteratingMetricManagerReports() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let source = TestMetricReportSource()
        let terminated = expectation(description: "The report sequence is terminated")
        source.continuation.onTermination = { _ in terminated.fulfill() }
        let sut = givenSut(enabledMetricReports: [.cpuCumulativeTime], metricsApi: TestInternalMetricsApi(), source: source)
        sut.receiveReports()

        // -- Act --
        sut.pauseReports()

        // -- Assert --
        wait(for: [terminated], timeout: 5)
    }

    // MARK: - Helpers

    /// The reports both APIs send. MetricManager doesn't report the scroll hitch time ratio, and
    /// only MetricManager reports hitch and animation totals and Metal frame rates.
    private static var reportsOfBothAPIs: Set<SentryMetricKit.MetricReport> {
        let reports = Set<SentryMetricKit.MetricReport>.all.subtracting([
            .animationScrollHitchTimeRatio,
            .animationTotalHitchTime,
            .animationTotalAnimationTime,
            .metalFramesPerSecond,
            .metalFrameCount,
            .metalActiveDrawingDuration
        ])
        #if os(macOS) || targetEnvironment(macCatalyst)
        // MetricManager doesn't report these on macOS.
        return reports.subtracting([
            .appTimeForeground, .appTimeBackground, .appTimeBackgroundAudio, .appTimeBackgroundLocation,
            .networkCellularUpload, .networkCellularDownload,
            .locationBestAccuracyTime, .locationBestAccuracyForNavigationTime, .locationNearestTenMetersTime,
            .locationHundredMetersTime, .locationKilometerTime, .locationThreeKilometersTime,
            .memoryPeakUsage, .memoryAverageSuspended,
            .displayAveragePixelLuminance,
            .diskSpaceBinaryFileSize, .diskSpaceBinaryFileCount, .diskSpaceDataFileSize, .diskSpaceDataFileCount,
            .diskSpaceCacheFolderSize, .diskSpaceCloneSize, .diskSpaceTotalUsed, .diskSpaceTotalCapacity
        ])
        #else
        return reports
        #endif // os(macOS) || targetEnvironment(macCatalyst)
    }

    private func givenMetricRecorder(enabledMetricReports: Set<SentryMetricKit.MetricReport>, metricsApi: TestInternalMetricsApi) -> SentryMXMetricRecorder {
        SentryMXMetricRecorder(
            enabledMetricReports: enabledMetricReports,
            metricsApi: metricsApi,
            releaseName: "io.sentry.app@2.0.0+20",
            bundleInfo: bundleInfo
        )
    }

    @available(iOS 27.0, macOS 27.0, *)
    private func givenSut(
        enabledMetricReports: Set<SentryMetricKit.MetricReport>,
        metricsApi: TestInternalMetricsApi,
        source: SentryMetricManagerSource = TestMetricReportSource()
    ) -> SentryMetricManager {
        SentryMetricManager(
            source: source,
            diagnosticCapturer: nil,
            metricRecorder: givenMetricRecorder(enabledMetricReports: enabledMetricReports, metricsApi: metricsApi)
        )
    }

    /// The legacy payload with the values of the fixtures in `SentryMXManagerMetricsTests`.
    @available(iOS 27.0, macOS 27.0, *)
    private func givenLegacyPayload() -> TestMXMetricPayload {
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
        payload.overrides.diskSpaceUsageMetrics = TestMXDiskSpaceUsageMetric()
        return payload
    }

    /// The `MetricResult` values matching `givenLegacyPayload()`, in MetricKit's Codable format.
    @available(iOS 27.0, macOS 27.0, *)
    private func legacyPayloadValues() -> [[String: Any]] {
        let cpu = TestMXCPUMetric()
        let exitsInForeground = TestMXForegroundExitData()
        let exitsInBackground = TestMXBackgroundExitData()
        let diskSpace = TestMXDiskSpaceUsageMetric()
        var values: [[String: Any]] = [
            ["cpuTimeMetric": ["value": seconds(cpu.cumulativeCPUTime)]],
            // The legacy fixture reports 5 kiloinstructions.
            ["cpuInstructionsCountMetric": ["value": 5_000]],
            ["gpuTimeMetric": ["value": seconds(TestMXGPUMetric().cumulativeGPUTime)]],
            ["totalWiFiUploadMetric": ["value": bytes(TestMXNetworkTransferMetric().cumulativeWifiUpload)]],
            ["totalWiFiDownloadMetric": ["value": bytes(TestMXNetworkTransferMetric().cumulativeWifiDownload)]],
            ["logicalDiskWritesMetric": ["value": bytes(TestMXDiskIOMetric().cumulativeLogicalWrites)]],
            ["hitchTimeMetric": [
                "ratio": ["value": 12, "unit": "ms per s"],
                "totalHitchTime": seconds(Measurement(value: 1, unit: .seconds)),
                "totalAnimationTime": seconds(Measurement(value: 10, unit: .seconds))
            ]],
            ["foregroundTerminationMetric": [
                "normalTerminationCount": exitsInForeground.cumulativeNormalAppExitCount,
                "memoryLimitTerminationCount": exitsInForeground.cumulativeMemoryResourceLimitExitCount,
                "badAccessTerminationCount": exitsInForeground.cumulativeBadAccessExitCount,
                "abnormalTerminationCount": exitsInForeground.cumulativeAbnormalExitCount,
                "illegalInstructionTerminationCount": exitsInForeground.cumulativeIllegalInstructionExitCount,
                "watchdogTerminationCount": exitsInForeground.cumulativeAppWatchdogExitCount
            ]],
            ["backgroundTerminationMetric": [
                "normalTerminationCount": exitsInBackground.cumulativeNormalAppExitCount,
                "memoryLimitTerminationCount": exitsInBackground.cumulativeMemoryResourceLimitExitCount,
                "highCPUTerminationCount": exitsInBackground.cumulativeCPUResourceLimitExitCount,
                "systemPressureTerminationCount": exitsInBackground.cumulativeMemoryPressureExitCount,
                "badAccessTerminationCount": exitsInBackground.cumulativeBadAccessExitCount,
                "abnormalTerminationCount": exitsInBackground.cumulativeAbnormalExitCount,
                "illegalInstructionTerminationCount": exitsInBackground.cumulativeIllegalInstructionExitCount,
                "watchdogTerminationCount": exitsInBackground.cumulativeAppWatchdogExitCount,
                "fileLockTerminationCount": exitsInBackground.cumulativeSuspendedWithLockedFileExitCount,
                "taskTimeoutTerminationCount": exitsInBackground.cumulativeBackgroundTaskAssertionTimeoutExitCount
            ]]
        ]
        #if !os(macOS) && !targetEnvironment(macCatalyst)
        let appTime = TestMXAppRunTimeMetric()
        let network = TestMXNetworkTransferMetric()
        let location = TestMXLocationActivityMetric()
        let memory = TestMXMemoryMetric()
        values += [
            ["totalForegroundTimeMetric": ["value": seconds(appTime.cumulativeForegroundTime)]],
            ["totalBackgroundTimeMetric": ["value": seconds(appTime.cumulativeBackgroundTime)]],
            ["totalBackgroundAudioTimeMetric": ["value": seconds(appTime.cumulativeBackgroundAudioTime)]],
            ["totalBackgroundLocationTimeMetric": ["value": seconds(appTime.cumulativeBackgroundLocationTime)]],
            ["totalCellularUploadMetric": ["value": bytes(network.cumulativeCellularUpload)]],
            ["totalCellularDownloadMetric": ["value": bytes(network.cumulativeCellularDownload)]],
            ["locationActivityTimeMetric": [
                "bestAccuracyForNavigation": seconds(location.cumulativeBestAccuracyForNavigationTime),
                "bestAccuracy": seconds(location.cumulativeBestAccuracyTime),
                "tenMeters": seconds(location.cumulativeNearestTenMetersAccuracyTime),
                "oneHundredMeter": seconds(location.cumulativeHundredMetersAccuracyTime),
                "oneKilometer": seconds(location.cumulativeKilometerAccuracyTime),
                "threeKilometers": seconds(location.cumulativeThreeKilometersAccuracyTime),
                "reducedAccuracy": seconds(Measurement(value: 7, unit: .seconds))
            ]],
            ["peakMemoryMetric": ["value": bytes(memory.peakMemoryUsage)]],
            ["suspendedMemoryMetric": ["value": ["average": bytes(memory.averageSuspendedMemory.averageMeasurement), "count": 4]]],
            ["pixelLuminanceMetric": ["value": ["average": ["value": 42, "unit": "apl"], "count": 4]]],
            ["totalFileCountMetric": ["binaryFileCount": diskSpace.totalBinaryFileCount, "dataFileCount": diskSpace.totalDataFileCount]],
            ["totalFileSizeMetric": [
                "binaryFileSize": bytes(diskSpace.totalBinaryFileSize),
                "cacheFolderSize": bytes(diskSpace.totalCacheFolderSize),
                "cloneSize": bytes(diskSpace.totalCloneSize),
                "dataFileSize": bytes(diskSpace.totalDataFileSize)
            ]],
            ["totalDiskSpaceCapacityMetric": [
                "capacity": bytes(diskSpace.totalDiskSpaceCapacity),
                "spaceUsed": bytes(diskSpace.totalDiskSpaceUsedSize)
            ]]
        ]
        #endif // !os(macOS) && !targetEnvironment(macCatalyst)
        return values
    }

    private func metalFrameRate(layerName: String, framesPerSecond: Double, frameCount: Int, activeDrawingSeconds: Double) -> [String: Any] {
        ["metalFrameRateMetric": [
            "framesPerSecond": ["value": framesPerSecond, "unit": "Hz"],
            "frameCount": frameCount,
            "activeDrawingDuration": seconds(Measurement(value: activeDrawingSeconds, unit: .seconds)),
            "layerName": layerName
        ]]
    }

    private static func givenEnvironment() -> [String: Any] {
        [
            "regionFormat": "US",
            "osVersion": ["platform": "iOS", "number": "18.6.2", "buildNumber": "22G100"],
            "deviceType": "iPhone18,1",
            "platformArchitecture": "arm64e",
            "lowPowerModeEnabled": false,
            "isTestFlightApp": false,
            "bundleIdentifier": "io.sentry.app",
            "applicationBuildVersion": "10",
            "latestApplicationVersion": "1.0.0",
            "includesMultipleApplicationVersions": false,
            "hasExceededStateLimit": false
        ]
    }

    private func intervalEntry(
        states: [[String: Any]] = [],
        duration: Measurement<UnitDuration> = Measurement(value: 24, unit: .hours),
        values: [[String: Any]]
    ) -> [String: Any] {
        ["states": states, "duration": seconds(duration), "values": values]
    }

    @available(iOS 27.0, macOS 27.0, *)
    private func givenReport(values: [[String: Any]], environment: [String: Any]? = givenEnvironment()) throws -> MetricKit.MetricReport {
        try givenReport(intervalEntries: [intervalEntry(values: values)], environment: environment)
    }

    /// Builds a report through its Codable format, because MetricKit doesn't let apps create one.
    @available(iOS 27.0, macOS 27.0, *)
    private func givenReport(intervalEntries: [[String: Any]], environment: [String: Any]? = givenEnvironment()) throws -> MetricKit.MetricReport {
        var report: [String: Any] = [
            "timeRange": [
                "begin": timeStampBegin.timeIntervalSinceReferenceDate,
                "end": timeStampEnd.timeIntervalSinceReferenceDate
            ],
            "stateEntries": [Any](),
            "intervalEntries": intervalEntries
        ]
        report["environment"] = environment
        let data = try JSONSerialization.data(withJSONObject: report)
        return try JSONDecoder().decode(MetricKit.MetricReport.self, from: data)
    }

    private func seconds(_ measurement: Measurement<UnitDuration>) -> [String: Any] {
        ["value": measurement.converted(to: .seconds).value, "unit": "s"]
    }

    private func bytes(_ measurement: Measurement<UnitInformationStorage>) -> [String: Any] {
        ["value": measurement.converted(to: .bytes).value, "unit": "B"]
    }
}

private final class TestMXMetricManager: SentryMXMetricManager {
    func add(_ subscriber: MXMetricManagerSubscriber) {}

    func remove(_ subscriber: MXMetricManagerSubscriber) {}
}

@available(iOS 27.0, macOS 27.0, *)
private final class TestMetricReportSource: SentryMetricManagerSource {
    let reports: AsyncStream<MetricKit.MetricReport>
    let continuation: AsyncStream<MetricKit.MetricReport>.Continuation

    init() {
        (reports, continuation) = AsyncStream.makeStream()
    }

    func makeDiagnosticReports() -> any AsyncSequence<MetricKit.DiagnosticReport, Never> {
        AsyncStream { $0.finish() }
    }

    func makeMetricReports() -> any AsyncSequence<MetricKit.MetricReport, Never> {
        reports
    }
}

#endif // (os(iOS) || os(macOS)) && compiler(>=6.4)
