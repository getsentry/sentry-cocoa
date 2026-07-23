#if ENABLE_KSCRASH
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry

final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
    let kscrashInstaller: MockKSCrashInstaller
    let testDispatchQueueWrapper: TestSentryDispatchQueueWrapper
    let fileManager: SentryFileManager?
    let dateProvider: SentryCurrentDateProvider
    var dispatchQueueWrapper: SentryDispatchQueueWrapper { testDispatchQueueWrapper }

    init(
        installer: MockKSCrashInstaller = .init(),
        dispatchQueueWrapper: TestSentryDispatchQueueWrapper = .init(),
        fileManager: SentryFileManager? = nil,
        dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider()
    ) {
        self.kscrashInstaller = installer
        self.testDispatchQueueWrapper = dispatchQueueWrapper
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }
}

final class MockKSCrashInstaller: SentryKSCrash.Installing {
    public var installCalls: [(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool)] = []
    public var shouldThrow: Error?
    public var crashedLastLaunch: Bool = false
    public var activeDurationSinceLastCrash: TimeInterval = 0
    public var sendAllReportsInvocations: [SentryStoredCrashReportProcessor] = []
    public var onSendAllReports: (() -> Void)?

    public init() {}

    public func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws {
        installCalls.append((installPath: installPath, monitors: monitors, enableSwapCxaThrow: enableSwapCxaThrow))
        if let error = shouldThrow { throw error }
    }

    public func sendAllReports(reportProcessor: SentryStoredCrashReportProcessor) {
        sendAllReportsInvocations.append(reportProcessor)
        onSendAllReports?()
    }
}
#endif
