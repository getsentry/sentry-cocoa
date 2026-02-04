import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryStandaloneAppStartTrackingIntegrationTests: NotificationCenterTestCase {

    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

        let options: Options
        let fileManager: SentryFileManager

        init() throws {
            let options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryStandaloneAppStartTrackingIntegrationTests")
            options.tracesSampleRate = 1.0
            options.enableStandaloneAppStartTransaction = true
            self.options = options

            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
        }

        func getSut(enableStandaloneAppStartTransaction: Bool = true, tracesSampleRate: NSNumber = 1.0) -> SentryStandaloneAppStartTrackingIntegration? {
            let options = self.options
            options.enableStandaloneAppStartTransaction = enableStandaloneAppStartTransaction
            options.tracesSampleRate = tracesSampleRate

            let container = SentryDependencyContainer.sharedInstance()
            container.fileManager = fileManager
            container.dateProvider = dateProvider

            return SentryStandaloneAppStartTrackingIntegration(
                with: options,
                dependencies: container
            )
        }

        func createAppStartMeasurement(type: SentryAppStartType = .cold) -> SentryAppStartMeasurement {
            let appStartTimestamp = dateProvider.date().addingTimeInterval(-1.0)
            return TestData.getAppStartMeasurement(
                type: type,
                appStartTimestamp: appStartTimestamp,
                runtimeInitSystemTimestamp: 1
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
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAppState()
        SentrySDKInternal.setAppStartMeasurement(nil)
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        clearTestState()
    }

    // MARK: - Integration Installation Tests

    func testIntegration_WhenEnabled_IsInstalled() {
        let sut = fixture.getSut(enableStandaloneAppStartTransaction: true)
        XCTAssertNotNil(sut, "Integration should be installed when enableStandaloneAppStartTransaction is true")
        sut?.uninstall()
    }

    func testIntegration_WhenDisabled_IsNotInstalled() {
        let sut = fixture.getSut(enableStandaloneAppStartTransaction: false)
        XCTAssertNil(sut, "Integration should not be installed when enableStandaloneAppStartTransaction is false")
    }

    func testIntegration_WhenTracingDisabled_IsNotInstalled() {
        let sut = fixture.getSut(enableStandaloneAppStartTransaction: true, tracesSampleRate: 0)
        XCTAssertNil(sut, "Integration should not be installed when tracing is disabled")
    }

    // MARK: - Extended App Launch Task Tests

    func testExtendedAppLaunchTask_WhenIntegrationEnabled_ReturnsTask() {
        let sut = fixture.getSut()
        defer { sut?.uninstall() }

        let task = SentryStandaloneAppStartTrackingIntegration.createExtendedAppLaunchTask()
        XCTAssertNotNil(task, "Should return an extended app launch task when integration is enabled")
    }

    func testExtendedAppLaunchTask_WhenIntegrationDisabled_ReturnsNil() {
        // Don't create an integration
        let task = SentryStandaloneAppStartTrackingIntegration.createExtendedAppLaunchTask()
        XCTAssertNil(task, "Should return nil when integration is not installed")
    }

    func testExtendedAppLaunchTask_CalledTwice_ReturnsNilSecondTime() {
        let sut = fixture.getSut()
        defer { sut?.uninstall() }

        let task1 = SentryStandaloneAppStartTrackingIntegration.createExtendedAppLaunchTask()
        let task2 = SentryStandaloneAppStartTrackingIntegration.createExtendedAppLaunchTask()

        XCTAssertNotNil(task1, "First call should return a task")
        XCTAssertNil(task2, "Second call should return nil")
    }

    // MARK: - SentryAppLaunchTask Tests

    func testAppLaunchTask_FinishCalledOnce_Works() {
        var finishCallCount = 0
        let task = SentryAppLaunchTask { _ in
            finishCallCount += 1
        }

        task.finish()
        task.finish() // Second call should be ignored

        XCTAssertEqual(finishCallCount, 1, "Finish callback should only be called once")
    }
}
#endif
