#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
import XCTest

class SentryKSCrashQueryTests: XCTestCase {

    // MARK: - installed

    func testInstalled_whenInstallerIsInstalled_shouldReturnTrue() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.installed = true
        let sut = SentryKSCrash.Query(installer: installer)

        // -- Act --
        let result = sut.installed

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testInstalled_whenInstallerIsNotInstalled_shouldReturnFalse() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.installed = false
        let sut = SentryKSCrash.Query(installer: installer)

        // -- Act --
        let result = sut.installed

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testInstalled_whenInstallerStateChangesAfterInit_shouldReflectCurrentState() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let sut = SentryKSCrash.Query(installer: installer)

        // -- Act --
        installer.installed = true

        // -- Assert --
        XCTAssertTrue(sut.installed)
    }

    // MARK: - crashedLastLaunch

    func testCrashedLastLaunch_whenInstallerCrashedLastLaunch_shouldReturnTrue() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = true
        let sut = SentryKSCrash.Query(installer: installer)

        // -- Act --
        let result = sut.crashedLastLaunch

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testCrashedLastLaunch_whenInstallerDidNotCrashLastLaunch_shouldReturnFalse() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = false
        let sut = SentryKSCrash.Query(installer: installer)

        // -- Act --
        let result = sut.crashedLastLaunch

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testCrashedLastLaunch_whenInstallerStateChangesAfterInit_shouldReflectCurrentState() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let sut = SentryKSCrash.Query(installer: installer)

        // -- Act --
        installer.crashedLastLaunch = true

        // -- Assert --
        XCTAssertTrue(sut.crashedLastLaunch)
    }
}
#endif
