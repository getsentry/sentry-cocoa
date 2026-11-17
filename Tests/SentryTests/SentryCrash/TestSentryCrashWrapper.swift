#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation

class TestSentryCrashReporterState: NSObject, SentryCrashReporterState {
    var internalInstalled = false
    var internalCrashedLastLaunch = false

    var installed: Bool { internalInstalled }
    var crashedLastLaunch: Bool { internalCrashedLastLaunch }
}

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
