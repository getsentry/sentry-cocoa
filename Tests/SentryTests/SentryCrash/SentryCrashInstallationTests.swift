@testable import Sentry
import SentryTestUtils
import XCTest

class SentryCrashTestInstallation2: SentryCrashInstallation {

    override init() {
        super.init(requiredProperties: [])
    }
}

class SentryCrashInstallationTests2: XCTestCase {

    var notificationCenter: TestNSNotificationCenterWrapper!

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
        XCTAssertEqual(5, notificationCenter.removeObserverWithNameInvocationsCount)
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

        #if SentryCrashCRASH_HAS_UIAPPLICATION
        XCTAssertEqual(55, notificationCenter.removeObserverWithNameInvocationsCount)
        #endif
    }

    // MARK: - Private

    private func getSut() -> SentryCrashTestInstallation2 {
        let installation = SentryCrashTestInstallation2()
        notificationCenter = TestNSNotificationCenterWrapper()
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper = notificationCenter
        return installation
    }

    private func assertReinstalled(_ installation: SentryCrashTestInstallation2,
                                   monitorsAfterInstall: SentryCrashMonitorType,
                                   crashHandlerDataAfterInstall: UnsafeMutablePointer<CrashHandlerData>?) {
        let sentryCrash = SentryDependencyContainer.sharedInstance().crashReporter
        XCTAssertNotNil(installation.g_crashHandlerData())
        XCTAssertEqual(monitorsAfterInstall, sentryCrash.monitoring)
        XCTAssertEqual(monitorsAfterInstall, sentrycrashcm_getActiveMonitors())
        XCTAssertNotNil(sentryCrash.onCrash)
        XCTAssertEqual(crashHandlerDataAfterInstall, installation.g_crashHandlerData())
        XCTAssertNotNil(sentrycrashcm_getEventCallback())
        XCTAssertTrue(sentrycrashccd_hasThreadStarted())

        assertReservedThreads(monitorsAfterInstall)
    }

    private func assertUninstalled(_ installation: SentryCrashTestInstallation2,
                                   monitorsAfterInstall: SentryCrashMonitorType) {
        let sentryCrash = SentryDependencyContainer.sharedInstance().crashReporter
        XCTAssertNil(installation.g_crashHandlerData())
        XCTAssertEqual(SentryCrashMonitorTypeNone, Int32(sentryCrash.monitoring.rawValue))
        XCTAssertEqual(SentryCrashMonitorTypeNone, Int32(sentrycrashcm_getActiveMonitors().rawValue))
        XCTAssertNil(sentryCrash.onCrash)
        XCTAssertNil(sentrycrashcm_getEventCallback())
        XCTAssertFalse(sentrycrashccd_hasThreadStarted())

        assertReservedThreads(monitorsAfterInstall)
    }

    private func assertReservedThreads(_ monitorsAfterInstall: SentryCrashMonitorType) {
        if monitorsAfterInstall == SentryCrashMonitorTypeMachException {
            XCTAssertTrue(sentrycrashcm_hasReservedThreads())
        } else {
            XCTAssertFalse(sentrycrashcm_hasReservedThreads())
        }
    }
}
