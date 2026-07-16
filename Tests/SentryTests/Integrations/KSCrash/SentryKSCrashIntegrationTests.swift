#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import KSCrashInstallations
import XCTest

class MockKSCrashDependencies: KSCrashIntegrationProvider {
    let kscrashInstaller: any KSCrashInstalling
    var dateProvider: SentryCurrentDateProvider {
        SentryDependencyContainer.sharedInstance().dateProvider
    }

    init(installer: any KSCrashInstalling = TestKSCrashInstaller()) {
        self.kscrashInstaller = installer
    }
}

class SentryKSCrashIntegrationTests: XCTestCase {

    private func makeOptions(enableCrashHandler: Bool = true) -> Options {
        let options = Options()
        options.enableCrashHandler = enableCrashHandler
        return options
    }

    func testInstallCalledOnInit() {
        let installer = TestKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)
        let options = makeOptions()

        let sut = SentryKSCrashIntegration(with: options, dependencies: deps)

        XCTAssertNotNil(sut)
        XCTAssertEqual(installer.installCalls.count, 1)
        XCTAssertEqual(installer.installCalls[0].installPath, options.cacheDirectoryPath)
        XCTAssertEqual(installer.installCalls[0].monitors, MonitorType.productionSafeMinimal.rawValue)
    }

    func testCrashedLastLaunchSetsFlag() {
        let installer = TestKSCrashInstaller()
        installer.crashedLastLaunch = true
        let deps = MockKSCrashDependencies(installer: installer)

        SentrySDKInternal.fatalDetected = false
        let sut = SentryKSCrashIntegration(with: makeOptions(), dependencies: deps)

        XCTAssertNotNil(sut)
        XCTAssertTrue(SentrySDKInternal.fatalDetected)
    }

    func testInstallFailureReturnsNil() {
        let installer = TestKSCrashInstaller()
        installer.shouldThrow = NSError(domain: "TestKSCrash", code: -99)
        let deps = MockKSCrashDependencies(installer: installer)

        let sut = SentryKSCrashIntegration(with: makeOptions(), dependencies: deps)

        XCTAssertNil(sut)
    }

    func testInitSkipsWhenCrashHandlerDisabled() {
        let installer = TestKSCrashInstaller()
        let deps = MockKSCrashDependencies(installer: installer)

        let sut = SentryKSCrashIntegration(with: makeOptions(enableCrashHandler: false), dependencies: deps)

        XCTAssertNil(sut)
        XCTAssertEqual(installer.installCalls.count, 0)
    }
}
#endif
