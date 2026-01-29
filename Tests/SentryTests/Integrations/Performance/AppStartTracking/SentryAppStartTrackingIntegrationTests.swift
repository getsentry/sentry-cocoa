import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackingIntegrationTests: NotificationCenterTestCase {

    private class Fixture {
        private let dateProvider = TestCurrentDateProvider()
        private let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

        let options = Options()
        let fileManager: SentryFileManager

        init() throws {
            options.tracesSampleRate = 0.1
            options.tracesSampler = { _ in return 0 }
            options.dsn = TestConstants.dsnAsString(username: "SentryAppStartTrackingIntegrationTests")

            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
        }

        func getSut(options: Options? = nil) throws -> SentryAppStartTrackingIntegration<SentryDependencyContainer> {
            return try XCTUnwrap(getOptionalSut(options: options))
        }
        
        func getOptionalSut(options: Options? = nil) -> SentryAppStartTrackingIntegration<SentryDependencyContainer>? {
            let container = SentryDependencyContainer.sharedInstance()
            container.fileManager = fileManager

            return SentryAppStartTrackingIntegration(
                with: options ?? self.options,
                dependencies: container
            )
        }
    }

    private var fixture: Fixture!

    override class func setUp() {
        super.setUp()
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        clearTestState()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        SentrySDKInternal.setAppStartMeasurement(nil)
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAppState()
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentrySDKInternal.setAppStartMeasurement(nil)
        clearTestState()
    }
    
    func testAppStartMeasuringEnabledAndSampleRate_properlySetupTracker() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }

        let tracker = sut.tracker
        try assertTrackerSetupAndRunning(tracker)
    }

    func testUnistall_stopsTracker() throws {
        let sut = try fixture.getSut()

        let tracker = sut.tracker
        try assertTrackerSetupAndRunning(tracker)
        sut.uninstall()

        XCTAssertFalse(tracker.isRunning, "AppStartTracking should not be running")
    }

    func testNoSampleRate_noIntegration() throws {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil

        let sut = fixture.getOptionalSut(options: options)
        XCTAssertNil(sut)
    }

    func testHybridSDKModeEnabled_properlySetupTracker() throws {
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true

        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil

        let sut = try fixture.getSut(options: options)
        defer {
            sut.uninstall()
        }

        let tracker = try XCTUnwrap(sut.tracker, "SentryAppStartTrackingIntegration should have a tracker")
        try assertTrackerSetupAndRunning(tracker)
    }

    func testOnlyAppStartMeasuringEnabled_noIntegration() throws {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil

        let sut = fixture.getOptionalSut(options: options)
        XCTAssertNil(sut)
    }

    func test_PerformanceTrackingDisabled_noIntegration() throws {
        let options = fixture.options
        options.enableAutoPerformanceTracing = false

        let sut = fixture.getOptionalSut(options: options)
        XCTAssertNil(sut)
    }

    func assertTrackerSetupAndRunning(_ tracker: SentryAppStartTracker) throws {
        XCTAssertNotNil(tracker.dispatchQueue, "Tracker does not have a dispatch queue.")

        XCTAssertIdentical(tracker.appStateManager, SentryDependencyContainer.sharedInstance().appStateManager)

        XCTAssertTrue(tracker.isRunning, "AppStartTracking should be running")
    }
    
}
#endif
