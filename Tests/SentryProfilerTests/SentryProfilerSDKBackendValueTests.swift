#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

final class SentryProfilerSDKBackendValueTests: XCTestCase {
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    func testCopyFrameMeasurements_whenTrackerHasFrames_shouldReturnSnapshot() throws {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let previousTracker = container.framesTracker
        defer { container.framesTracker = previousTracker }
        let clock = TestCurrentDateProvider()
        let tracker = TestFramesTracker(
            displayLinkWrapper: TestDisplayLinkWrapper(dateProvider: clock),
            dateProvider: clock,
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
            notificationCenter: TestNSNotificationCenterWrapper(),
            delayedFramesTracker: TestDelayedWrapper(keepDelayedFramesDuration: 0, dateProvider: clock)
        )
        let slow: [[String: NSNumber]] = [["timestamp": 10, "value": 20]]
        let frozen: [[String: NSNumber]] = [["timestamp": 30, "value": 40]]
        let rates: [[String: NSNumber]] = [["timestamp": 10, "value": 60]]
        tracker.expectedFrames = SentryScreenFrames(total: 3, frozen: 1, slow: 1,
            slowFrameTimestamps: slow, frozenFrameTimestamps: frozen, frameRateTimestamps: rates)
        container.framesTracker = tracker
        let backend = SentryDefaultProfilerSDKBackend()

        // -- Act --
        let snapshot = try XCTUnwrap(backend.copyFrameMeasurements())

        // -- Assert --
        XCTAssertEqual(snapshot.slowFrameTimestamps, slow)
        XCTAssertEqual(snapshot.frozenFrameTimestamps, frozen)
        XCTAssertEqual(snapshot.frameRateTimestamps, rates)
    }
#endif

    func testTimestamp_whenClockInjected_shouldReturnPairedValues() {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let previousClock = container.dateProvider
        defer { container.dateProvider = previousClock }
        let clock = TestCurrentDateProvider()
        clock.setDate(date: Date(timeIntervalSince1970: 123))
        clock.advance(by: 1)
        container.dateProvider = clock
        let backend = SentryDefaultProfilerSDKBackend()

        // -- Act --
        let timestamp = backend.timestamp()

        // -- Assert --
        XCTAssertEqual(timestamp.systemTime, 1_000_000_000)
        XCTAssertEqual(timestamp.dateInterval, 124)
    }

    func testScheduleTimer_whenCancelled_shouldInvalidateUnderlyingTimer() throws {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let previousFactory = container.timerFactory
        defer { container.timerFactory = previousFactory }
        let factory = TestSentryNSTimerFactory(currentDateProvider: TestCurrentDateProvider())
        container.timerFactory = factory
        let backend = SentryDefaultProfilerSDKBackend()
        let cancellation = try XCTUnwrap(backend.scheduleTimer(withInterval: 3_600, repeats: false, block: {}))
        let timer = try XCTUnwrap(factory.overrides?.timer)
        XCTAssertTrue(timer.isValid)

        // -- Act --
        cancellation.cancel()

        // -- Assert --
        XCTAssertFalse(timer.isValid)
    }

    func testSystemMetrics_whenOneReadingFails_shouldKeepOtherReadings() throws {
        // -- Arrange --
        let wrapper = TestSentrySystemWrapper()
        wrapper.overrides.cpuUsage = 25
        wrapper.overrides.memoryFootprintError = NSError(domain: "profiling-test", code: 1)
#if arch(arm) || arch(arm64)
        wrapper.overrides.cpuEnergyUsage = 500
#endif
        let backend = SentryDefaultProfilerSDKBackend()
        backend.systemWrapper = wrapper

        // -- Act --
        let readings = try XCTUnwrap(backend.systemMetrics())

        // -- Assert --
        XCTAssertEqual(readings.cpuUsage, 25)
        XCTAssertNil(readings.memoryFootprintBytes)
#if arch(arm) || arch(arm64)
        XCTAssertEqual(readings.cpuEnergyUsage, 500)
#else
        XCTAssertNil(readings.cpuEnergyUsage)
#endif
    }

    func testSerializedDebugImages_whenProviderHasImages_shouldReturnWireValues() throws {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let previousProvider = container.debugImageProvider
        defer { container.debugImageProvider = previousProvider }
        let image = DebugMeta()
        image.debugID = "profiling-debug-id"
        image.codeFile = "profiling-image"
        image.imageAddress = "0x1000"
        image.imageSize = 4_096
        image.type = "macho"
        let provider = TestDebugImageProvider()
        provider.debugImages = [image]
        container.debugImageProvider = provider
        let backend = SentryDefaultProfilerSDKBackend()

        // -- Act --
        let images = try XCTUnwrap(backend.serializedDebugImages())

        // -- Assert --
        XCTAssertEqual(images.count, 1)
        let serialized = try XCTUnwrap(images.first)
        XCTAssertEqual(serialized["debug_id"] as? String, "profiling-debug-id")
        XCTAssertEqual(serialized["code_file"] as? String, "profiling-image")
        XCTAssertEqual(serialized["image_addr"] as? String, "0x1000")
        XCTAssertEqual(serialized["image_size"] as? Int, 4_096)
        XCTAssertEqual(serialized["type"] as? String, "macho")
    }

}
#endif
