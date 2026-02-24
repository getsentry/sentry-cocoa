@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryCrashTestInstallation: SentryCrashInstallation {

    override init() {
        super.init(requiredProperties: [])
    }
}

class SentryCrashInstallationTests: XCTestCase {

    private var notificationCenter: TestNSNotificationCenterWrapper!

    override func tearDown() {
        super.tearDown()
        SentryDependencyContainer.reset()
    }

    // MARK: - Tests

    func testUninstall() {
        let installation = getSut()

        installation.install("/private/tmp")

        let monitorsAfterInstall = SentryDependencyContainer.sharedInstance().crashReporter.monitoring

        installation.uninstall()

        assertUninstalled(installation, monitorsAfterInstall: monitorsAfterInstall)
    }

    func testUninstall_CallsRemoveObservers() {
        let installation = getSut()

        installation.install("/private/tmp")
        installation.uninstall()

        #if SENTRY_UIKIT_AVAILABLE
        XCTAssertEqual(5, notificationCenter.removeObserverWithNameInvocations.invocations.count)
        #endif
    }

    func testUninstall_Install() {
        let installation = getSut()

        installation.install("/private/tmp")

        let monitorsAfterInstall = SentryDependencyContainer.sharedInstance().crashReporter.monitoring
        let crashHandlerDataAfterInstall = installation.g_crashHandlerData()

        for _ in 0..<10 {
            installation.uninstall()
            installation.install("/private/tmp")
        }

        assertReinstalled(installation,
                          monitorsAfterInstall: monitorsAfterInstall,
                          crashHandlerDataAfterInstall: crashHandlerDataAfterInstall)

        installation.uninstall()
        assertUninstalled(installation, monitorsAfterInstall: monitorsAfterInstall)

        installation.install("/private/tmp")
        assertReinstalled(installation,
                          monitorsAfterInstall: monitorsAfterInstall,
                          crashHandlerDataAfterInstall: crashHandlerDataAfterInstall)

        #if os(iOS) || os(tvOS)
        XCTAssertEqual(55, notificationCenter.removeObserverWithNameAndObjectInvocations.invocations.count)
        #endif // os(iOS) || os(tvOS)
    }

    // MARK: - Private

    private func getSut() -> SentryCrashTestInstallation {
        let installation = SentryCrashTestInstallation()
        notificationCenter = TestNSNotificationCenterWrapper()
        let container = SentryDependencyContainer.sharedInstance()
        container.notificationCenterWrapper = notificationCenter
        let bridge = SentryCrashBridge(
            notificationCenterWrapper: notificationCenter,
            dateProvider: container.dateProvider,
            crashReporter: container.crashReporter
        )
        installation.bridge = bridge
        return installation
    }

    private func assertReinstalled(_ installation: SentryCrashTestInstallation,
                                   monitorsAfterInstall: UInt32,
                                   crashHandlerDataAfterInstall: UnsafeMutablePointer<CrashHandlerData>?) {
        let sentryCrash = SentryDependencyContainer.sharedInstance().crashReporter
        XCTAssertNotNil(installation.g_crashHandlerData())
        XCTAssertEqual(monitorsAfterInstall, sentryCrash.monitoring)
        XCTAssertEqual(monitorsAfterInstall, sentrycrashcm_getActiveMonitors().rawValue)
        XCTAssertTrue(sentryCrash.hasOnCrash())
        XCTAssertEqual(crashHandlerDataAfterInstall, installation.g_crashHandlerData())
        XCTAssertNotNil(sentrycrashcm_getEventCallback())
        XCTAssertTrue(sentrycrashccd_hasThreadStarted())

        assertReservedThreads(monitorsAfterInstall)
    }

    private func assertUninstalled(_ installation: SentryCrashTestInstallation,
                                   monitorsAfterInstall: UInt32) {
        let sentryCrash = SentryDependencyContainer.sharedInstance().crashReporter
        XCTAssertNil(installation.g_crashHandlerData())
        XCTAssertEqual(SentryCrashMonitorTypeNone, Int32(sentryCrash.monitoring))
        XCTAssertEqual(SentryCrashMonitorTypeNone, Int32(sentrycrashcm_getActiveMonitors().rawValue))
        XCTAssertFalse(sentryCrash.hasOnCrash())
        XCTAssertNil(sentrycrashcm_getEventCallback())
        XCTAssertFalse(sentrycrashccd_hasThreadStarted())

        assertReservedThreads(monitorsAfterInstall)
    }

    private func assertReservedThreads(_ monitorsAfterInstall: UInt32) {
        if monitorsAfterInstall & SentryCrashMonitorTypeMachException.rawValue == 1 {
            XCTAssertTrue(sentrycrashcm_hasReservedThreads())
        } else {
            XCTAssertFalse(sentrycrashcm_hasReservedThreads())
        }
    }
}
