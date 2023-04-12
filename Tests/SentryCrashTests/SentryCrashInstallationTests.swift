import SentryTestUtils
import XCTest

class SentryCrashTestInstallation: SentryCrashInstallation {
    override init() {
        super.init(requiredProperties: [])
    }
}

final class SentryCrashInstallationTests: XCTestCase {
    struct Fixture {
        let notificationCenter = TestNSNotificationCenterWrapper()
        let crashInstallation = SentryCrashTestInstallation()

        init() {
            SentryCrash.sharedInstance().setSentryNSNotificationCenterWrapper(notificationCenter)
        }
    }

    var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    func testUninstall() {
        fixture.crashInstallation.install()
        let monitorsAfterInstall = SentryCrash.sharedInstance().monitoring
        fixture.crashInstallation.uninstall()
        assertUninstalled(monitorsAfterInstall: monitorsAfterInstall)
    }

    func testUninstall_CallsRemoveObservers() {
        fixture.crashInstallation.install()
        fixture.crashInstallation.uninstall()
#if os(iOS) || os(tvOS)
        XCTAssertEqual(5, fixture.notificationCenter.removeObserverWithNameInvocationsCount)
#endif
    }

    func testUninstall_Install() {
        fixture.crashInstallation.install()
        let monitorsAfterInstall = SentryCrash.sharedInstance().monitoring
        let crashHandlerDataAfterInstall = fixture.crashInstallation.g_crashHandlerData()

        // To ensure multiple calls in a row work
        for _ in 0..<10 {
            fixture.crashInstallation.uninstall()
            fixture.crashInstallation.install()
        }

        assertReinstalled(monitorsAfterInstall: monitorsAfterInstall, crashHandlerDataAfterInstall: crashHandlerDataAfterInstall)

        fixture.crashInstallation.uninstall()
        assertUninstalled(monitorsAfterInstall: monitorsAfterInstall)

        fixture.crashInstallation.install()
        assertReinstalled(monitorsAfterInstall: monitorsAfterInstall, crashHandlerDataAfterInstall: crashHandlerDataAfterInstall)

        #if os(iOS) || os(tvOS)
        XCTAssertEqual(55, fixture.notificationCenter.removeObserverWithNameInvocationsCount)
        #endif
    }
}

private extension SentryCrashInstallationTests {
    func assertUninstalled(monitorsAfterInstall: SentryCrashMonitorType) {
        XCTAssertNil(fixture.crashInstallation.g_crashHandlerData())
        XCTAssertEqual(SentryCrashMonitorTypeNone, SentryCrash.sharedInstance().monitoring)
        XCTAssertEqual(SentryCrashMonitorTypeNone, sentrycrashcm_getActiveMonitors())
        XCTAssertNil(SentryCrash.sharedInstance().onCrash)
        XCTAssertNil(sentrycrashcm_getEventCallback())
        XCTAssertFalse(sentrycrashccd_hasThreadStarted())

        assertReservedThreads(monitorsAfterInstall: monitorsAfterInstall)

    }

    func assertReinstalled(monitorsAfterInstall: SentryCrashMonitorType, crashHandlerDataAfterInstall: UnsafeMutablePointer<CrashHandlerData>?) {
        XCTAssertNotNil(fixture.crashInstallation.g_crashHandlerData())
        XCTAssertEqual(monitorsAfterInstall, SentryCrash.sharedInstance().monitoring)
        XCTAssertEqual(monitorsAfterInstall, sentrycrashcm_getActiveMonitors())
        XCTAssertNotNil(SentryCrash.sharedInstance().onCrash)
        XCTAssertEqual(crashHandlerDataAfterInstall, fixture.crashInstallation.g_crashHandlerData())
        XCTAssertNotNil(sentrycrashcm_getEventCallback())
        XCTAssert(sentrycrashccd_hasThreadStarted())

        assertReservedThreads(monitorsAfterInstall: monitorsAfterInstall)
    }

    func assertReservedThreads(monitorsAfterInstall: SentryCrashMonitorType) {
        if monitorsAfterInstall == SentryCrashMonitorTypeMachException {
            XCTAssert(sentrycrashcm_hasReservedThreads())
        } else {
            XCTAssertFalse(sentrycrashcm_hasReservedThreads())
        }
    }
}
