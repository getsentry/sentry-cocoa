#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry

final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
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
}

final class MockKSCrashInstaller: SentryKSCrash.Installing {
    public var installCalls: [(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool)] = []
    public var shouldThrow: Error?
    public var crashedLastLaunch: Bool = false
    public var sendAllReportsInvocations: [SentryCrashReportProcessor] = []

    public init() {}

    public func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws {
        installCalls.append((installPath: installPath, monitors: monitors, enableSwapCxaThrow: enableSwapCxaThrow))
        if let error = shouldThrow { throw error }
    }

    public func sendAllReports(reportProcessor: SentryCrashReportProcessor) {
        sendAllReportsInvocations.append(reportProcessor)
    }
}
#endif
