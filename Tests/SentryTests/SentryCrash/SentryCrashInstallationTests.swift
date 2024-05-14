@testable import Sentry
import SentryTestUtils
import XCTest

class SentryCrashTestInstallation: SentryCrashInstallation {

    override init() {
        super.init(requiredProperties: [])
    }
}

class SentryCrashInstallationTests: XCTestCase {

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

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        XCTAssertEqual(55, notificationCenter.removeObserverWithNameInvocationsCount)
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    }

    // MARK: - Private

    private func getSut() -> SentryCrashTestInstallation {
        let installation = SentryCrashTestInstallation()
        notificationCenter = TestNSNotificationCenterWrapper()
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper = notificationCenter
        return installation
    }

    private func assertReinstalled(_ installation: SentryCrashTestInstallation,
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

    private func assertUninstalled(_ installation: SentryCrashTestInstallation,
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
        if monitorsAfterInstall.rawValue & SentryCrashMonitorTypeMachException.rawValue == 1 {
            XCTAssertTrue(sentrycrashcm_hasReservedThreads())
        } else {
            XCTAssertFalse(sentrycrashcm_hasReservedThreads())
        }
    }
}
