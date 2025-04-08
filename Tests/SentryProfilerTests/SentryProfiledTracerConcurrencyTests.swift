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
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.givenSdkWithHub()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        sentry_stopAndDiscardLaunchProfileTracer()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)

        // Act
        try fixture.allowContinuousProfilerToStop()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchProfileStartWithAdditionalSpan() throws {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.givenSdkWithHub()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        let span = try fixture.newTransaction(rootSpan: true)

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

        // Act
        try fixture.allowContinuousProfilerToStop()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    class ProfiledViewController: UIViewController {}

    func testLaunchProfileStartAndStopWithTTFD() throws {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.enableTimeToFullDisplayTracing = true
        fixture.options.add(inAppInclude: "uikitcore")
        SentryDependencyContainer.sharedInstance()
        SentrySDK.start(options: fixture.options)

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        let uivc = ProfiledViewController(nibName: nil, bundle: nil)
        uivc.loadView()
        uivc.viewWillAppear(false)
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 2)

        // Act
        sentry_stopAndDiscardLaunchProfileTracer()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)

        // Act
        uivc.viewDidAppear(false)
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)

        // Act
        try fixture.allowContinuousProfilerToStop()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartAndStopTransaction() throws {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.givenSdkWithHub()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        let span = try fixture.newTransaction()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        span.finish()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)

        // Act
        try fixture.allowContinuousProfilerToStop()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManualLifecycleDoesntTrackLaunchWithSpan() throws {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.givenSdkWithHub()

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
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.givenSdkWithHub()

        // Assert
        XCTAssertEqual(_gInFlightRootSpans, 0)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        let span = try fixture.newTransaction()

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
