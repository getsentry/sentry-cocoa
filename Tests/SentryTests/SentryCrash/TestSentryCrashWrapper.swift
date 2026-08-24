@_spi(Private) @testable import Sentry
import Foundation

/// Protocol-based test double for SentryCrashReporter.
/// Implements the protocol directly -- no subclassing of the concrete class.
class TestSentryCrashReporter: NSObject, SentryCrashReporter {

    // MARK: - Test Properties

    var internalInstalled = false
    var internalCrashedLastLaunch = false
    var internalDurationFromCrashStateInitToLastCrash: TimeInterval = 0
    var internalActiveDurationSinceLastCrash: TimeInterval = 0
    var internalIsSimulatorBuild = false
    var internalIntrospectMemory: Bool = true

    // MARK: - Convenience Init (backward compatibility)

    /// Compatibility init so the test files that call
    /// `TestSentryCrashWrapper(processInfoWrapper:)` compile without changes.
    convenience init(processInfoWrapper: SentryProcessInfoSource) {
        self.init()
    }

    // MARK: - SentryCrashReporter Protocol

    var installed: Bool { internalInstalled }
    var crashedLastLaunch: Bool { internalCrashedLastLaunch }
    var durationFromCrashStateInitToLastCrash: TimeInterval { internalDurationFromCrashStateInitToLastCrash }
    var activeDurationSinceLastCrash: TimeInterval { internalActiveDurationSinceLastCrash }
    var isSimulatorBuild: Bool { internalIsSimulatorBuild }
    var introspectMemory: Bool {
        get { internalIntrospectMemory }
        set { internalIntrospectMemory = newValue }
    }
}

/// Backward compatibility alias so test files that reference
/// `TestSentryCrashWrapper` by name compile without modification.
typealias TestSentryCrashWrapper = TestSentryCrashReporter

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
