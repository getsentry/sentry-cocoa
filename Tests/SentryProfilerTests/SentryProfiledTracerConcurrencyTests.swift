import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
final class SentryProfiledTracerConcurrencyTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!

    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
}

// MARK: Trace lifecycle UI Profiling
extension SentryProfiledTracerConcurrencyTests {
    func testLaunchProfileStartAndStop() throws {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.tracesSampleRate = 1
        options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        try XCTUnwrap(sentry_launchTracer).finish()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchProfileStartWithAdditionalSpan() throws {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.tracesSampleRate = 1
        options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        
        let hub = TestHub(client: TestClient(options: options), andScope: nil)
        sentry_sdkInitProfilerTasks(options, hub)

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        let context = TransactionContext(trace: SentryId(), spanId: SpanId(), parentId: nil, operation: "test-operaton", spanDescription: "test-second-root-span", sampled: .yes)
        let span = SentryTracer(transactionContext: context, hub: hub, configuration: .init())

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 2)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        
        // Act
        span.finish()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling()) 
        
        // Act
        XCTAssertNotNil(sentry_launchTracer)
        sentry_stopAndDiscardLaunchProfileTracer()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)

    }

    func testStartAndStopTransaction() throws {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.tracesSampleRate = 1
        options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        let span = SentrySDK.startTransaction(name: "test", operation: "operation")

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        // Act
        span.finish()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManualLifecycleDoesntTrackLaunchWithSpan() throws {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.tracesSampleRate = 1
        options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)
    }

    func testManualLifecycleDoesntTrackRootSpan() throws {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.tracesSampleRate = 1
        options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        let span = SentrySDK.startTransaction(name: "test", operation: "operation")

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        span.finish()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
