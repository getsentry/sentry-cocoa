#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
import Testing

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

    private func makeSut(options: Options, installer: TestKSCrashInstaller) -> SentryKSCrash.Integration<MockKSCrashDependencies>? {
        SentryKSCrash.Integration(with: options, dependencies: MockKSCrashDependencies(ksCrashInstaller: installer))
    }

    @Test
    func testName_shouldBeSentryKSCrashIntegration() {
        #expect(SentryKSCrash.Integration<MockKSCrashDependencies>.name == "SentryKSCrashIntegration")
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
        #expect(config.maxReportCount == 5)
        #expect(config.reportCleanupPolicy == .always)
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
