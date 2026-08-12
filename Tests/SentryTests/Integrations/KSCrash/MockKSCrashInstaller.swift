#if SDK_V10
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry

final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
    typealias Installing = MockKSCrashInstaller

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
    public var activeDurationSinceLastCrash: TimeInterval = 0
    public var sendAllReportsInvocations: [SentryStoredCrashReportProcessor] = []
    public var sendAllReportsDispatchQueues: [SentryDispatchQueueWrapper] = []
    public var sendAllReportsProcessingSessions: [SentryKSCrash.ReportProcessingSession] = []
    public var onSendAllReports: (() -> Void)?
    public var setUserInfoInvocations: [[String: Any]] = []

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

    public func setUserInfo(_ userInfo: [String: Any]) {
        setUserInfoInvocations.append(userInfo)
    }

    public func sendAllReports(
        reportProcessor: SentryStoredCrashReportProcessor,
        dispatchQueue: SentryDispatchQueueWrapper,
        processingSession: SentryKSCrash.ReportProcessingSession
    ) {
        sendAllReportsInvocations.append(reportProcessor)
        sendAllReportsDispatchQueues.append(dispatchQueue)
        sendAllReportsProcessingSessions.append(processingSession)
        onSendAllReports?()
    }
}
#endif
