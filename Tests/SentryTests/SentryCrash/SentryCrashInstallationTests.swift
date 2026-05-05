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

    func testInstall_SetsUncaughtExceptionHandler() throws {
        // NSException is part of SentryCrashMonitorTypeDebuggerUnsafe, so the
        // monitor is masked out when running under a debugger (e.g. Xcode).
        // setEnabled(true) is never called in that case, so uncaughtExceptionHandler
        // is never assigned and the assertion would always fail.
        try XCTSkipIf(sentrycrashdebug_isBeingTraced(), "NSException monitor is disabled under the debugger")

        // Verifies the bridge is set before sentrycrash_install so that when
        // the NSException monitor calls setEnabled(true), g_bridge is non-nil
        // and uncaughtExceptionHandler gets assigned on the crash reporter.
        // Previously, setBridge was called after install, so the assignment
        // was a no-op via ObjC nil messaging.
        let installation = getSut()
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        // Uninstall first to reset g_installed and disable all monitors.
        // g_installed is a static that persists across tests; if it's
        // already 1, sentrycrash_install short-circuits and monitors are
        // never re-enabled through the full setEnabled(true) path.
        crashReporter.uninstall()

        installation.install("/private/tmp")
        defer { installation.uninstall() }

        XCTAssertNotNil(
            crashReporter.uncaughtExceptionHandler,
            "uncaughtExceptionHandler should be set after install because the bridge must be available when the NSException monitor is enabled"
        )
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
        container.crashReporter.setBridge(bridge)
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
