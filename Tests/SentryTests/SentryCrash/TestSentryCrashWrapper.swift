@_spi(Private) @testable import Sentry
import Foundation

class TestSentryCrashReporterState: NSObject, SentryCrashReporterState {
    var internalInstalled = false
    var internalCrashedLastLaunch = false

    var installed: Bool { internalInstalled }
    var crashedLastLaunch: Bool { internalCrashedLastLaunch }
}

#if !SDK_V10
/// V9 test double for the broad SentryCrash reporter adapter.
final class TestSentryCrashReporter: TestSentryCrashReporterState, SentryCrashReporter {
    var internalDurationFromCrashStateInitToLastCrash: TimeInterval = 0
    var internalActiveDurationSinceLastCrash: TimeInterval = 0
    var internalIsSimulatorBuild = false
    var internalIntrospectMemory: Bool = true

    convenience init(processInfoWrapper: SentryProcessInfoSource) {
        self.init()
    }

    var durationFromCrashStateInitToLastCrash: TimeInterval { internalDurationFromCrashStateInitToLastCrash }
    var activeDurationSinceLastCrash: TimeInterval { internalActiveDurationSinceLastCrash }
    var isSimulatorBuild: Bool { internalIsSimulatorBuild }
    var introspectMemory: Bool {
        get { internalIntrospectMemory }
        set { internalIntrospectMemory = newValue }
    }
}

typealias TestSentryCrashWrapper = TestSentryCrashReporter
#endif // !SDK_V10

final class TestSentryApplicationStateProvider: NSObject, SentryApplicationStateProvider {
    var isApplicationInForeground = true
}

final class TestSentryMemoryMetricsProvider: SentryMemoryMetricsProvider {
    var freeMemorySize: UInt64 = 0
    var appMemorySize: UInt64 = 0
    var usableMemorySize: UInt64 = 0
    var totalMemorySize: UInt64 = 0
}

final class TestSentryScopeContextEnricher: NSObject, SentryScopeContextEnricher {
    var enrichScopeCalled = false

    func enrichScope(_ scope: Scope) {
        enrichScopeCalled = true
    }
}
