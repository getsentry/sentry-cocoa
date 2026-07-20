#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import Testing

extension Tag {
    @Tag static var ksCrashIntegration: Self
}

struct SentryKSCrashIntegrationTests {
    // MARK: - Helpers
    private struct Fixture {
        let installer = MockKSCrashInstaller()
        lazy var deps = MockKSCrashDependencies(installer: installer)

        func makeOptions(enableCrashHandler: Bool = true) -> Options {
            let options = Options()
            options.enableCrashHandler = enableCrashHandler
            return options
        }
    }

    // MARK: - Install
    @Test(.tags(.ksCrashIntegration))
    func install_whenCrashHandlerEnabled_shouldCallInstallOnce() {
        // -- Arrange --
        var fixture = Fixture()
        let options = fixture.makeOptions()

        // -- Act --
        let sut = SentryKSCrash.Integration(with: options, dependencies: fixture.deps)

        // -- Assert --
        #expect(sut != nil)
        #expect(fixture.installer.installCalls.count == 1)
        #expect(fixture.installer.installCalls[0].installPath == options.cacheDirectoryPath)
    }

    @Test(.tags(.ksCrashIntegration))
    func install_whenCrashHandlerEnabled_shouldUseProductionSafeMonitors() {
        // -- Arrange --
        var fixture = Fixture()

        // -- Act --
        _ = SentryKSCrash.Integration(with: fixture.makeOptions(), dependencies: fixture.deps)

        // -- Assert --
        #expect(fixture.installer.installCalls[0].monitors == SentryKSCrash.productionSafeMonitors.rawValue)
    }

    @Test(.tags(.ksCrashIntegration))
    func install_whenCrashHandlerDisabled_shouldSkipInstall() {
        // -- Arrange --
        var fixture = Fixture()

        // -- Act --
        let sut = SentryKSCrash.Integration(with: fixture.makeOptions(enableCrashHandler: false), dependencies: fixture.deps)

        // -- Assert --
        #expect(sut == nil)
        #expect(fixture.installer.installCalls.isEmpty)
    }

    @Test(.tags(.ksCrashIntegration))
    func install_whenInstallThrows_shouldReturnNil() {
        // -- Arrange --
        var fixture = Fixture()
        fixture.installer.shouldThrow = NSError(domain: "TestKSCrash", code: -99)

        // -- Act --
        let sut = SentryKSCrash.Integration(with: fixture.makeOptions(), dependencies: fixture.deps)

        // -- Assert --
        #expect(sut == nil)
    }

    // MARK: - Crash detection
    @Test(.tags(.ksCrashIntegration))
    func install_whenCrashedLastLaunch_shouldSetFatalDetected() {
        // -- Arrange --
        var fixture = Fixture()
        fixture.installer.crashedLastLaunch = true
        SentrySDKInternal.fatalDetected = false

        // -- Act --
        let sut = SentryKSCrash.Integration(with: fixture.makeOptions(), dependencies: fixture.deps)

        // -- Assert --
        #expect(sut != nil)
        #expect(SentrySDKInternal.fatalDetected)
    }

    @Test(.tags(.ksCrashIntegration))
    func install_whenDidNotCrashLastLaunch_shouldNotSetFatalDetected() {
        // -- Arrange --
        var fixture = Fixture()
        fixture.installer.crashedLastLaunch = false
        SentrySDKInternal.fatalDetected = false

        // -- Act --
        _ = SentryKSCrash.Integration(with: fixture.makeOptions(), dependencies: fixture.deps)

        // -- Assert --
        #expect(!SentrySDKInternal.fatalDetected)
    }
}

// MARK: - Test doubles
final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
    let kscrashInstaller: MockKSCrashInstaller

    init(installer: MockKSCrashInstaller = .init()) {
        self.kscrashInstaller = installer
    }
}
#endif
