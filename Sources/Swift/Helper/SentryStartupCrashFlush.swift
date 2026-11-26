internal import _SentryPrivate
import Foundation

/// Startup-crash persistence owned by the crash reporter.
///
/// Waits for optional session-replay recovery encode, then flushes with the
/// remaining budget. Recovery wait is capped so flush always gets at least
/// `minimumFlushDuration`. No pending recovery means a full `duration` flush.
@_spi(Private) @objc public final class SentryStartupCrashFlush: NSObject {
    /// Total time budget for waiting on recovery encode plus flushing envelopes.
    @objc public static let duration: TimeInterval = 5

    /// Minimum time reserved for flushing envelopes after recovery wait.
    @objc public static let minimumFlushDuration: TimeInterval = 1

    /// Time allowed for recovery encode before flush starts.
    static var recoveryWaitTimeout: TimeInterval {
        max(0, duration - minimumFlushDuration)
    }

    /// Flush timeout after spending `elapsed` waiting on recovery.
    static func flushTimeout(afterWaiting elapsed: TimeInterval) -> TimeInterval {
        max(minimumFlushDuration, duration - elapsed)
    }

    private let idleGate: SentryReplayRecoveryIdleGate

    /// - Parameter idleGate: Recovery gate shared with session replay for this SDK lifecycle.
    @objc public init(idleGate: SentryReplayRecoveryIdleGate) {
        self.idleGate = idleGate
        super.init()
    }

    /// Waits for optional replay recovery, then flushes with the remaining budget.
    @objc public func flushAfterReplayRecoveryIdle() {
        let start = CFAbsoluteTimeGetCurrent()
        _ = idleGate.waitForIdle(timeout: Self.recoveryWaitTimeout)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        SentrySDKInternal.flush(timeout: Self.flushTimeout(afterWaiting: elapsed))
    }
}
