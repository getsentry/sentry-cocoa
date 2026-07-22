#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry

final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
    typealias Installing = MockKSCrashInstaller

    let kscrashInstaller: MockKSCrashInstaller
    let testDispatchQueueWrapper: TestSentryDispatchQueueWrapper
    var dispatchQueueWrapper: SentryDispatchQueueWrapper { testDispatchQueueWrapper }

    init(
        installer: MockKSCrashInstaller = .init(),
        dispatchQueueWrapper: TestSentryDispatchQueueWrapper = .init()
    ) {
        self.kscrashInstaller = installer
        self.testDispatchQueueWrapper = dispatchQueueWrapper
    }

    func getKSCrashInstaller() -> MockKSCrashInstaller {
        return kscrashInstaller
    }
}

final class MockKSCrashInstaller: SentryKSCrash.Installing {
    public var installCalls: [
        (
            installPath: String,
            monitors: UInt,
            enableMemoryIntrospection: Bool,
            enableSwapCxaThrow: Bool
        )
    ] = []
    public var uninstallCallCount = 0
    public var shouldThrow: Error?
    public var crashedLastLaunch: Bool = false
    public var installed: Bool = false
    public var sendAllReportsInvocations: [SentryCrashReportProcessor] = []

    public init() {}

    public func install(
        installPath: String,
        monitors: UInt,
        enableMemoryIntrospection: Bool,
        enableSwapCxaThrow: Bool
    ) throws {
        installCalls.append(
            (
                installPath: installPath,
                monitors: monitors,
                enableMemoryIntrospection: enableMemoryIntrospection,
                enableSwapCxaThrow: enableSwapCxaThrow
            )
        )
        if let error = shouldThrow { throw error }
        installed = true
    }

    public func uninstall() {
        uninstallCallCount += 1
        installed = false
    }

    public func sendAllReports(reportProcessor: SentryCrashReportProcessor) {
        sendAllReportsInvocations.append(reportProcessor)
    }
}
#endif
