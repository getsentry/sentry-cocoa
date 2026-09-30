internal import _SentryPrivate
import Foundation

/// Startup-crash persistence owned by the crash reporter.
///
/// Waits for optional session-replay recovery encode, then flushes with whatever
/// remains of the 5s budget. No pending recovery means a full 5s flush, matching
/// the historical startup-crash path.
@_spi(Private) @objc public final class SentryStartupCrashFlush: NSObject {
    /// Total time budget for waiting on recovery encode plus flushing envelopes.
    @objc public static let duration: TimeInterval = 5

    /// Waits for optional replay recovery, then flushes with the remaining budget.
    @objc public static func flushAfterReplayRecoveryIdle() {
        let budget = duration
        let start = CFAbsoluteTimeGetCurrent()
        _ = SentryDependencyContainer.sharedInstance().replayRecoveryIdleGate.waitForIdle(timeout: budget)
        let remaining = max(0, budget - (CFAbsoluteTimeGetCurrent() - start))
        SentrySDKInternal.flush(timeout: remaining)
    }
}
