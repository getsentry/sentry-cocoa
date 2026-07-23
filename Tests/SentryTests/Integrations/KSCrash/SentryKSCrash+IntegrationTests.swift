#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

class SentryKSCrashIntegrationTests: XCTestCase {
    private var cacheDirectoryPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        clearTestState()
        cacheDirectoryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
    }

    override func tearDownWithError() throws {
        clearTestState()
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
        let installer = MockKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()

        let sut = SentryKSCrash.Integration(with: options, dependencies: deps)

        XCTAssertNotNil(sut)
        XCTAssertEqual(installer.installCalls.count, 1)
        XCTAssertEqual(installer.installCalls[0].monitors, SentryKSCrash.productionSafeMonitors)
        XCTAssertEqual(installer.sendAllReportsInvocations.count, 1)
        XCTAssertEqual(deps.testDispatchQueueWrapper.dispatchAsyncCalled, 1)
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
        let installer = MockKSCrashInstaller()
        installer.shouldThrow = NSError(domain: "TestKSCrash", code: -99)
        let deps = MockKSCrashDependencies(installer: installer)

        let sut = SentryKSCrash.Integration(with: makeOptions(), dependencies: deps)

        XCTAssertNil(sut)
        XCTAssertEqual(installer.sendAllReportsInvocations.count, 0)
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
        XCTAssertEqual(installer.sendAllReportsInvocations.count, 0)
    }
}
#endif
