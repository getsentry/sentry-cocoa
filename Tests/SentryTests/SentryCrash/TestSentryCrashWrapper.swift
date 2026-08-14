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
    var internalFreeMemorySize: UInt64 = 0
    var internalAppMemorySize: UInt64 = 0
    var internalSystemInfo: [String: Any] = [:]
    var internalIntrospectMemory: Bool = true
    var binaryCacheStarted = false
    var binaryCacheStopped = false
    var enrichScopeCalled = false

    // MARK: - Convenience Init (backward compatibility)

    /// Compatibility init so the test files that call
    /// `TestSentryCrashWrapper(processInfoWrapper:)` compile without changes.
    convenience init(processInfoWrapper: SentryProcessInfoSource) {
        self.init()
        self.internalProcessInfoWrapper = processInfoWrapper
    }

    // MARK: - SentryCrashReporter Protocol

    var installed: Bool { internalInstalled }
    var crashedLastLaunch: Bool { internalCrashedLastLaunch }
    var durationFromCrashStateInitToLastCrash: TimeInterval { internalDurationFromCrashStateInitToLastCrash }
    var activeDurationSinceLastCrash: TimeInterval { internalActiveDurationSinceLastCrash }
    var isSimulatorBuild: Bool { internalIsSimulatorBuild }
    var freeMemorySize: UInt64 { internalFreeMemorySize }
    var appMemorySize: UInt64 { internalAppMemorySize }
    var systemInfo: [String: Any] { internalSystemInfo }
    var introspectMemory: Bool {
        get { internalIntrospectMemory }
        set { internalIntrospectMemory = newValue }
    }

    private var internalProcessInfoWrapper: SentryProcessInfoSource = ProcessInfo.processInfo
    var processInfoWrapper: SentryProcessInfoSource { internalProcessInfoWrapper }

    func startBinaryImageCache() {
        binaryCacheStarted = true
    }

    func stopBinaryImageCache() {
        binaryCacheStopped = true
    }

    func enrichScope(_ scope: Scope) {
        enrichScopeCalled = true
    }
}

/// Backward compatibility alias so test files that reference
/// `TestSentryCrashWrapper` by name compile without modification.
typealias TestSentryCrashWrapper = TestSentryCrashReporter

final class TestSentryApplicationStateProvider: NSObject, SentryApplicationStateProvider {
    var isApplicationInForeground = true
}
