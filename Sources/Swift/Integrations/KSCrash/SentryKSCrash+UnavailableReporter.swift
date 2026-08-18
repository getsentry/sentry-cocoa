#if SDK_V10
import Foundation

extension SentryKSCrash {
    /// Keeps remaining legacy-shaped consumers buildable while their narrow capabilities are
    /// extracted. Installation state comes from `SentryKSCrash.Query`.
    final class UnavailableReporter: NSObject, SentryCrashReporter {
        var introspectMemory = false
        var installed: Bool { false }
        var crashedLastLaunch: Bool { false }
        var durationFromCrashStateInitToLastCrash: TimeInterval { 0 }
        var activeDurationSinceLastCrash: TimeInterval { 0 }

        var isSimulatorBuild: Bool {
#if targetEnvironment(simulator)
            true
#else
            false
#endif
        }
    }
}
#endif // SDK_V10
