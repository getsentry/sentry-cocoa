#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

// Same condition as SentryMXManagerMetricsTests, which defines TestInternalMetricsApi.
#if os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))

final class SentryMXMetricRecorderTests: XCTestCase {

    private typealias HistogramBucket = SentryMXMetricRecorder.HistogramBucket

    // MARK: - Histogram Value Limit

    func testRecordHistogram_whenRareBucketScalesBelowOneValue_shouldKeepOneValue() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(metricsApi: metricsApi)
        let buckets = [
            HistogramBucket(lowerBound: 0.25, upperBound: 0.5, count: 999),
            HistogramBucket(lowerBound: 10, upperBound: 20, count: 1)
        ]

        // -- Act --
        sut.recordHistogram(.responsivenessHangTime, buckets, unit: .second, givenContext(sut))

        // -- Assert --
        let values = metricsApi.recordedMetrics.map(\.value)
        XCTAssertEqual(values.filter { $0 == 0.375 }.count, 100)
        XCTAssertEqual(values.filter { $0 == 15 }.count, 1)
        XCTAssertEqual(values.count, 101)
    }

    func testRecordHistogram_whenAllBucketsScaleBelowOneValue_shouldKeepOneValuePerBucket() {
        // -- Arrange --
        let metricsApi = TestInternalMetricsApi()
        let sut = givenSut(metricsApi: metricsApi)
        let buckets = (0..<250).map { index in
            HistogramBucket(lowerBound: Double(index), upperBound: Double(index + 1), count: 1)
        }

        // -- Act --
        sut.recordHistogram(.responsivenessHangTime, buckets, unit: .second, givenContext(sut))

        // -- Assert --
        XCTAssertEqual(metricsApi.recordedMetrics.map(\.value), (0..<250).map { Double($0) + 0.5 })
    }

    // MARK: - Helpers

    private func givenSut(metricsApi: TestInternalMetricsApi) -> SentryMXMetricRecorder {
        SentryMXMetricRecorder(
            enabledMetricReports: [.responsivenessHangTime],
            metricsApi: metricsApi,
            releaseName: "io.sentry.app@2.0.0+20",
            bundleInfo: [:]
        )
    }

    private func givenContext(_ sut: SentryMXMetricRecorder) -> SentryMXMetricRecorder.Context {
        sut.context(
            begin: Date(timeIntervalSince1970: 1_800_000_000),
            end: Date(timeIntervalSince1970: 1_800_086_400),
            appVersion: "2.0.0",
            appBuild: "20",
            includesMultipleApplicationVersions: false,
            osVersion: nil
        )
    }
}

#endif // os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))
