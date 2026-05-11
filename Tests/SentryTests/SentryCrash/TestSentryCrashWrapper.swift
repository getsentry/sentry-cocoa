import Foundation
@_spi(Private) @testable import Sentry

/// Protocol-based test double for SentryCrashReporter.
/// Implements the protocol directly -- no subclassing of the concrete class.
class TestSentryCrashReporter: NSObject, SentryCrashReporter {

    // MARK: - Test Properties

    var internalCrashedLastLaunch = false
    var internalDurationFromCrashStateInitToLastCrash: TimeInterval = 0
    var internalActiveDurationSinceLastCrash: TimeInterval = 0
    var internalIsBeingTraced = false
    var internalIsSimulatorBuild = false
    var internalIsApplicationInForeground = true
    var internalFreeMemorySize: UInt64 = 0
    var internalAppMemorySize: UInt64 = 0
    var internalSystemInfo: [String: Any] = [:]
    var enrichScopeCalled = false

    // MARK: - Convenience Init (backward compatibility)

    /// Compatibility init so the test files that call
    /// `TestSentryCrashWrapper(processInfoWrapper:)` compile without changes.
    convenience init(processInfoWrapper: SentryProcessInfoSource) {
        self.init()
        self.internalProcessInfoWrapper = processInfoWrapper
    }

    // MARK: - SentryCrashReporter Protocol

    var crashedLastLaunch: Bool { internalCrashedLastLaunch }
    var durationFromCrashStateInitToLastCrash: TimeInterval { internalDurationFromCrashStateInitToLastCrash }
    var activeDurationSinceLastCrash: TimeInterval { internalActiveDurationSinceLastCrash }
    var isBeingTraced: Bool { internalIsBeingTraced }
    var isSimulatorBuild: Bool { internalIsSimulatorBuild }
    var isApplicationInForeground: Bool { internalIsApplicationInForeground }
    var freeMemorySize: UInt64 { internalFreeMemorySize }
    var appMemorySize: UInt64 { internalAppMemorySize }
    var systemInfo: [String: Any] { internalSystemInfo }

    private var internalProcessInfoWrapper: SentryProcessInfoSource = ProcessInfo.processInfo
    var processInfoWrapper: SentryProcessInfoSource { internalProcessInfoWrapper }

    func enrichScope(_ scope: Scope) {
        enrichScopeCalled = true
    }
}

/// Backward compatibility alias so test files that reference
/// `TestSentryCrashWrapper` by name compile without modification.
typealias TestSentryCrashWrapper = TestSentryCrashReporter
