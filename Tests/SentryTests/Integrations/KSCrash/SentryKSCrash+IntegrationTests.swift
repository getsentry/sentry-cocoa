#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

class SentryKSCrashIntegrationTests: XCTestCase {
    private var cacheDirectoryPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        SentrySDKInternal.fatalDetected = false
        cacheDirectoryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
    }

    override func tearDownWithError() throws {
        SentrySDKInternal.fatalDetected = false
        if FileManager.default.fileExists(atPath: cacheDirectoryPath) {
            try FileManager.default.removeItem(atPath: cacheDirectoryPath)
        }
        try super.tearDownWithError()
    }

    private func makeOptions(enableCrashHandler: Bool = true) -> Options {
        let options = Options()
        options.enableCrashHandler = enableCrashHandler
        options.cacheDirectoryPath = cacheDirectoryPath
        return options
    }

    func testInstall_whenCrashHandlerEnabled_shouldCallInstallOnce() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()

        // -- Act --
        let sut = SentryKSCrash.Integration(with: options, dependencies: deps)

        // -- Assert --
        XCTAssertNotNil(sut)
        XCTAssertEqual(installer.installCalls.count, 1)
        XCTAssertEqual(installer.installCalls[0].monitors, SentryKSCrash.productionSafeMonitors)
        XCTAssertEqual(installer.sendAllReportsInvocations.count, 1)
        XCTAssertEqual(deps.testDispatchQueueWrapper.dispatchAsyncCalled, 1)
    }

    func testInstall_whenMemoryIntrospectionEnabled_shouldEnableMemoryIntrospection() throws {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()
        options.enableMemoryIntrospection = true

        // -- Act --
        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        // -- Assert --
        let installCall = try XCTUnwrap(installer.installCalls.first)
        XCTAssertTrue(installCall.enableMemoryIntrospection)
    }

    func testInstall_whenMemoryIntrospectionDisabled_shouldDisableMemoryIntrospection() throws {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()
        options.enableMemoryIntrospection = false

        // -- Act --
        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        // -- Assert --
        let installCall = try XCTUnwrap(installer.installCalls.first)
        XCTAssertFalse(installCall.enableMemoryIntrospection)
    }

    func testInstall_whenCrashHandlerEnabled_shouldAppendKSCrashBundleSubdirectory() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()
        let expectedPath = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: options.cacheDirectoryPath,
            bundleInfo: Bundle.main.infoDictionary
        ).path

        // -- Act --
        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        // -- Assert --
        XCTAssertEqual(installer.installCalls[0].installPath, expectedPath)
    }

    // MARK: - installPath helper

    func testInstallPath_appendsKSCrashAndBundleName() {
        // -- Arrange --
        let cacheDirectory = "/var/mobile/Containers/Data/app"
        let bundleInfo = ["CFBundleName": "MyApp"]

        // -- Act --
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: cacheDirectory,
            bundleInfo: bundleInfo
        )

        // -- Assert --
        XCTAssertEqual(result.path, "/var/mobile/Containers/Data/app/KSCrash/MyApp")
    }

    func testInstallPath_sanitizesSlashesInBundleName() {
        // -- Arrange
        let cacheDirectory = "/cache"
        let bundleInfo = ["CFBundleName": "My/App/Name"]

        // -- Act --
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: cacheDirectory,
            bundleInfo: bundleInfo
        )

        // -- Assert
        XCTAssertEqual(result.path, "/cache/KSCrash/My-App-Name")
    }

    func testInstallPath_fallsBackToUnknown_whenBundleInfoIsNil() {
        // -- Arrange --
        let cacheDirectory = "/cache"
        let bundleInfo: [String: Any]? = nil

        // -- Act --
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: cacheDirectory,
            bundleInfo: bundleInfo
        )

        // -- Assert --
        XCTAssertEqual(result.path, "/cache/KSCrash/Unknown")
    }

    func testInstallPath_fallsBackToUnknown_whenCFBundleNameKeyMissing() {
        // -- Arrange
        let cacheDirectory = "/cache"
        let bundleInfo = ["CFBundleIdentifier": "com.example.app"]

        // -- Act --
        let result = SentryKSCrash.Integration<MockKSCrashDependencies>.installPath(
            for: cacheDirectory,
            bundleInfo: bundleInfo
        )

        // -- Assert --
        XCTAssertEqual(result.path, "/cache/KSCrash/Unknown")
    }

    func testInstall_whenCrashedLastLaunch_shouldStoreCurrentSessionAsCrashedBeforeSendingReports() throws {
        let options = makeOptions()
        let dateProvider = TestCurrentDateProvider()
        let now = Date(timeIntervalSince1970: 10_000)
        dateProvider.setDate(date: now)
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let fileManager = try TestFileManager(
            options: options,
            dateProvider: dateProvider,
            dispatchQueueWrapper: dispatchQueue
        )
        fileManager.storeCurrentSession(
            SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        )

        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = true
        installer.activeDurationSinceLastCrash = 5
        var sessionStoredBeforeSendingReports = false
        installer.onSendAllReports = {
            sessionStoredBeforeSendingReports = fileManager.readCrashedSession() != nil
                && fileManager.readCurrentSession() == nil
        }
        let deps = MockKSCrashDependencies(
            installer: installer,
            dispatchQueueWrapper: dispatchQueue,
            fileManager: fileManager,
            dateProvider: dateProvider
        )

        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        XCTAssertTrue(sessionStoredBeforeSendingReports)
        XCTAssertNil(fileManager.readCurrentSession())
        let crashedSession = try XCTUnwrap(fileManager.readCrashedSession())
        XCTAssertEqual(crashedSession.status, .crashed)
        XCTAssertEqual(
            try XCTUnwrap(crashedSession.timestamp).timeIntervalSince1970,
            now.addingTimeInterval(-5).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testInstall_whenLastLaunchDidNotCrash_shouldKeepCurrentSession() throws {
        let options = makeOptions()
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let fileManager = try TestFileManager(
            options: options,
            dateProvider: dateProvider,
            dispatchQueueWrapper: dispatchQueue
        )
        fileManager.storeCurrentSession(
            SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        )
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(
            installer: installer,
            dispatchQueueWrapper: dispatchQueue,
            fileManager: fileManager,
            dateProvider: dateProvider
        )

        _ = SentryKSCrash.Integration(with: options, dependencies: deps)

        XCTAssertNotNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }

    func testInstall_whenInstallThrows_shouldReturnNil() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.shouldThrow = NSError(domain: "TestKSCrash", code: -99)
        let deps = MockKSCrashDependencies(installer: installer)
        SentryDependencyContainer.sharedInstance().kscrashQuery = SentryKSCrash.Query(installer: installer)

        // -- Act --
        let sut = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        // -- Assert --
        XCTAssertNil(sut)
        XCTAssertEqual(installer.sendAllReportsInvocations.count, 0)
    }

    // MARK: - Last-run crash APIs

    func testInstall_whenCrashedLastLaunch_shouldSetFatalDetected() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = true
        let deps = MockKSCrashDependencies(installer: installer)

        // -- Act --
        _ = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        // -- Assert --
        XCTAssertTrue(SentrySDKInternal.fatalDetected)
    }

    func testInstall_whenDidNotCrashLastLaunch_shouldNotSetFatalDetected() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        installer.crashedLastLaunch = false
        let deps = MockKSCrashDependencies(installer: installer)

        // -- Act --
        _ = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        // -- Assert --
        XCTAssertFalse(SentrySDKInternal.fatalDetected)
    }

    func testInstall_whenInstallSucceeds_shouldMarkInstallerInstalled() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        SentryDependencyContainer.sharedInstance().kscrashQuery = SentryKSCrash.Query(installer: installer)

        // -- Act --
        _ = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        // -- Assert --
        XCTAssertTrue(installer.installed)
        XCTAssertTrue(SentrySDKInternal.crashReporterInstalled)
    }

    func testInstall_whenInstallThrows_shouldNotSetCrashReporterInstalled() {
        // -- Arrange
        let installer = MockKSCrashInstaller()
        installer.shouldThrow = NSError(domain: "TestKSCrash", code: -99)
        let deps = MockKSCrashDependencies(installer: installer)
        SentryDependencyContainer.sharedInstance().kscrashQuery = SentryKSCrash.Query(installer: installer)

        // -- Act --
        _ = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        // -- Assert --
        XCTAssertFalse(installer.installed)
        XCTAssertFalse(SentrySDKInternal.crashReporterInstalled)
    }

    func testInstall_whenCrashHandlerDisabled_shouldSkipInstall() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)

        // -- Act --
        let sut = SentryKSCrash.Integration(with: makeOptions(enableCrashHandler: false), dependencies: deps)

        // -- Assert --
        XCTAssertNil(sut)
        XCTAssertEqual(installer.installCalls.count, 0)
        XCTAssertFalse(installer.installed)
        XCTAssertEqual(installer.sendAllReportsInvocations.count, 0)
    }

    func testUninstall_shouldClearInstallerInstalled() {
        // -- Arrange --
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        SentryDependencyContainer.sharedInstance().kscrashQuery = SentryKSCrash.Query(installer: installer)
        let sut = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)
        XCTAssertTrue(installer.installed)
        XCTAssertTrue(SentrySDKInternal.crashReporterInstalled)

        // -- Act --
        sut?.uninstall()

        // -- Assert --
        XCTAssertEqual(installer.uninstallCallCount, 1)
        XCTAssertFalse(installer.installed)
        XCTAssertFalse(SentrySDKInternal.crashReporterInstalled)
    }
}
#endif
