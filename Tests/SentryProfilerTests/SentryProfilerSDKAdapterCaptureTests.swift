#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
@_spi(Private) @testable import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import SentryTestUtilsObjC
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import SentryTestUtilsObjCpp
import XCTest

final class SentryProfilerSDKAdapterCaptureTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!

    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }

    override func tearDown() {
        // These tests replace process-wide SDK and profiling dependencies.
        // swiftlint:disable:next avoid_clear_test_state
        clearTestState()
        super.tearDown()
    }

    func testTransmitChunk_whenEnrichmentUnavailable_shouldCaptureSamplesAndMetrics() throws {
        // -- Arrange --
        let adapter = SentryProfilerSDKAdapter.shared
        let previousBackend = try XCTUnwrap(adapter.target)
        let debugImageProvider = TestDebugImageProvider()
        debugImageProvider.debugImages = []
        SentryDependencyContainer.sharedInstance().debugImageProvider = debugImageProvider
        let backend = sentry_test_createProfilerBackendWithoutEnrichment()
        adapter.setTarget(backend)
        defer {
            withExtendedLifetime(backend) {
                SentryContinuousProfiler.stopTimerAndCleanup()
            }
            adapter.setTarget(previousBackend)
        }
        SentryContinuousProfiler.start()
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        profiler.state = SentryProfilerState()
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(
            to: profiler.state, threadID: 1, threadPriority: 0, threadName: "test", addresses: [0x1])
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(
            to: profiler.state, threadID: 1, threadPriority: 0, threadName: "test", addresses: [0x2])
        profiler.metricProfiler.recordMetrics()

        // -- Act --
        SentryContinuousProfiler.transmitChunkEnvelope()

        // -- Assert --
        let client = try XCTUnwrap(fixture.client)
        XCTAssertEqual(client.captureEnvelopeInvocations.count, 1)
        let envelope = try XCTUnwrap(client.captureEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        let data = try XCTUnwrap(item.data)
        let chunk = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let profile = try XCTUnwrap(chunk["profile"] as? [String: Any])
        XCTAssertEqual((profile["samples"] as? [[String: Any]])?.count, 2)
        XCTAssertNil(chunk["debug_meta"])
        let measurements = try XCTUnwrap(chunk["measurements"] as? [String: Any])
        XCTAssertNotNil(measurements["cpu_usage"])
        XCTAssertNotNil(measurements["memory_footprint"])
        XCTAssertNil(measurements["slow_frame_renders"])
        XCTAssertNil(measurements["frozen_frame_renders"])
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

}
#endif
