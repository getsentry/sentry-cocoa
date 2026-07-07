#if ENABLE_KSCRASH
import KSCrashRecording
@_spi(Private) @testable import Sentry
import Testing

/// Tests for the behaviour `SentryKSCrashIntegration` has today: it validates
/// `enableCrashHandler`, builds a KSCrash configuration matching the legacy
/// SentryCrash setup, installs it through the injected installer, and records that the
/// crash reporter is installed.
///
/// The suite is `.serialized` because `installsCrashReporterFlag` mutates the global
/// `SentrySDKInternal.crashReporterInstalled`, which is reset in `init`.
///
/// Note: Swift Testing requires macOS 10.15+, so the test targets raise their macOS
/// deployment target to 10.15 in `SentryTests.xcconfig`. The Swift Testing macros reject
/// an `@available` annotation, so the deployment target is the only lever.
@Suite(.serialized)
struct SentryKSCrashIntegrationTests {

    private enum TestError: Error {
        case installFailed
    }

    init() {
        SentrySDKInternal.crashReporterInstalled = false
    }

    private func makeOptions(enableCrashHandler: Bool) -> Options {
        let options = Options()
        options.enableCrashHandler = enableCrashHandler
        return options
    }

    private func makeSut(options: Options, installer: TestKSCrashInstaller) -> SentryKSCrashIntegration<MockKSCrashDependencies>? {
        SentryKSCrashIntegration(with: options, dependencies: MockKSCrashDependencies(ksCrashInstaller: installer))
    }

    @Test
    func testName_shouldBeSentryKSCrashIntegration() {
        #expect(SentryKSCrashIntegration<MockKSCrashDependencies>.name == "SentryKSCrashIntegration")
    }

    @Test
    func testInit_whenCrashHandlerDisabled_shouldNotInstall() {
        // -- Arrange --
        let installer = TestKSCrashInstaller()

        // -- Act --
        let sut = makeSut(options: makeOptions(enableCrashHandler: false), installer: installer)

        // -- Assert --
        #expect(sut == nil)
        #expect(installer.installCallCount == 0)
    }

    @Test
    func testInit_whenCrashHandlerEnabled_shouldInstallOnce() {
        // -- Arrange --
        let installer = TestKSCrashInstaller()

        // -- Act --
        let sut = makeSut(options: makeOptions(enableCrashHandler: true), installer: installer)

        // -- Assert --
        #expect(sut != nil)
        #expect(installer.installCallCount == 1)
    }

    @Test
    func testInit_whenCrashHandlerEnabled_shouldInstallConfigurationMatchingSentryCrash() throws {
        // -- Arrange --
        let installer = TestKSCrashInstaller()
        let options = makeOptions(enableCrashHandler: true)

        // -- Act --
        _ = makeSut(options: options, installer: installer)

        // -- Assert --
        let config = try #require(installer.installedConfiguration)
        #expect(config.monitors == [.machException, .signal, .cppException, .nsException, .applicationState])
        #expect(config.enableMemoryIntrospection)
        #expect(config.installPath == options.cacheDirectoryPath)
        #expect(config.reportStoreConfiguration.maxReportCount == 5)
        #expect(config.reportStoreConfiguration.reportCleanupPolicy == .always)
    }

    @Test
    func testInit_whenInstallThrows_shouldReturnNil() {
        // -- Arrange --
        let installer = TestKSCrashInstaller()
        installer.errorToThrow = TestError.installFailed

        // -- Act --
        let sut = makeSut(options: makeOptions(enableCrashHandler: true), installer: installer)

        // -- Assert --
        #expect(sut == nil)
    }

    @Test
    func testInit_whenInstallSucceeds_shouldSetCrashReporterInstalled() {
        // -- Act --
        _ = makeSut(options: makeOptions(enableCrashHandler: true), installer: TestKSCrashInstaller())

        // -- Assert --
        #expect(SentrySDKInternal.crashReporterInstalled)
    }

    @Test
    func testInit_whenInstallThrows_shouldNotSetCrashReporterInstalled() {
        // -- Arrange --
        let installer = TestKSCrashInstaller()
        installer.errorToThrow = TestError.installFailed

        // -- Act --
        _ = makeSut(options: makeOptions(enableCrashHandler: true), installer: installer)

        // -- Assert --
        #expect(SentrySDKInternal.crashReporterInstalled == false)
    }
}
#endif
