#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryKSCrashIntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    override func tearDown() {
        super.tearDown()
    }

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
        let expectedPath = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: options.cacheDirectoryPath,
            bundleInfo: Bundle.main.infoDictionary
        ).path

        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        XCTAssertEqual(installer.installCalls[0].installPath, expectedPath)
    }

    // MARK: - installPath helper

    func testInstallPath_appendsKSCrashAndBundleName() {
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: "/var/mobile/Containers/Data/app",
            bundleInfo: ["CFBundleName": "MyApp"]
        )
        XCTAssertEqual(result.path, "/var/mobile/Containers/Data/app/KSCrash/MyApp")
    }

    func testInstallPath_sanitizesSlashesInBundleName() {
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: "/cache",
            bundleInfo: ["CFBundleName": "My/App/Name"]
        )
        XCTAssertEqual(result.path, "/cache/KSCrash/My-App-Name")
    }

    func testInstallPath_fallsBackToUnknown_whenBundleInfoIsNil() {
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: "/cache",
            bundleInfo: nil
        )
        XCTAssertEqual(result.path, "/cache/KSCrash/Unknown")
    }

    func testInstallPath_fallsBackToUnknown_whenCFBundleNameKeyMissing() {
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: "/cache",
            bundleInfo: ["CFBundleIdentifier": "com.example.app"]
        )
        XCTAssertEqual(result.path, "/cache/KSCrash/Unknown")
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
