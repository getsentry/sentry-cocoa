#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryKSCrashIntegrationTests: XCTestCase {
    private func makeOptions(enableCrashHandler: Bool = true) -> Options {
        let options = Options()
        options.enableCrashHandler = enableCrashHandler
        return options
    }

    func testInstall_whenCrashHandlerEnabled_shouldCallInstallOnce() {
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()

        let sut = SentryKSCrash.Integration(with: options, dependencies: deps)

        XCTAssertNotNil(sut)
        XCTAssertEqual(installer.installCalls.count, 1)
        XCTAssertEqual(installer.installCalls[0].monitors, SentryKSCrash.productionSafeMonitors)
    }

    func testInstall_whenCrashHandlerEnabled_shouldAppendKSCrashBundleSubdirectory() {
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()
        let bundleID = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
        let expectedPath = URL(fileURLWithPath: options.cacheDirectoryPath)
            .appendingPathComponent("KSCrash")
            .appendingPathComponent(bundleID)
            .path

        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        XCTAssertEqual(installer.installCalls[0].installPath, expectedPath)
    }

    func testInstall_whenCrashedLastLaunch_shouldSetFatalDetected() {
        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = true
        let deps = MockKSCrashDependencies(installer: installer)

        SentrySDKInternal.fatalDetected = false
        SentrySDKInternal.crashHandlerDetectedCrash = false
        let sut = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        XCTAssertNotNil(sut)
        XCTAssertTrue(SentrySDKInternal.fatalDetected)
        XCTAssertTrue(SentrySDKInternal.crashHandlerDetectedCrash)
    }

    func testInstall_whenInstallThrows_shouldReturnNil() {
        let installer = MockKSCrashInstaller()
        installer.shouldThrow = NSError(domain: "TestKSCrash", code: -99)
        let deps = MockKSCrashDependencies(installer: installer)

        let sut = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        XCTAssertNil(sut)
    }

    // MARK: - Last-run crash APIs

    func testLastRunStatus_whenCrashedLastLaunch_shouldReturnDidCrash() {
        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = true
        let deps = MockKSCrashDependencies(installer: installer)

        SentrySDKInternal.fatalDetected = false
        SentrySDKInternal.crashReporterInstalled = false
        _ = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        XCTAssertEqual(SentrySDK.lastRunStatus, .didCrash)
    }

    func testInstall_whenCrashHandlerDisabled_shouldSkipInstall() {
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)

        let sut = SentryKSCrash.Integration(with: makeOptions(enableCrashHandler: false), dependencies: deps)

        XCTAssertNil(sut)
        XCTAssertEqual(installer.installCalls.count, 0)
    }
}
#endif
