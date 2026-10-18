import Foundation

/// Tracks in-flight session-replay crash recovery so startup-crash flush can wait
/// for encode without owning replay, and without replay owning flush.
///
/// `waitForIdle` returns immediately when nothing is pending, including when
/// session replay is not installed.
@_spi(Private) @objc public final class SentryReplayRecoveryIdleGate: NSObject {
    private struct State {
        var pending = 0
        var claimed = false
    }

    private let state = SentryMutex(State())
    private let group = DispatchGroup()

    /// Claims recovery for this SDK lifecycle. The first caller wins; later callers get `false`.
    /// Does not delete `replay.last`; that stays until encode finishes so a kill can still recover.
    @objc public func tryClaim() -> Bool {
        state.withLock { current in
            if current.claimed { return false }
            current.claimed = true
            return true
        }
    }

    /// Marks recovery encode as in-flight. Must be paired with `end`.
    @objc public func begin() {
        // Keep pending and the group in the same critical section so waitForIdle
        // cannot observe work and then wait on an empty group, which succeeds.
        state.withLock {
            $0.pending += 1
            group.enter()
        }
    }

    /// Marks one in-flight recovery encode as finished. Extra calls are ignored.
    @objc public func end() {
        state.withLock { current in
            guard current.pending > 0 else { return }
            current.pending -= 1
            group.leave()
        }
    }

    /// Waits until every `begin` has a matching `end`, or `timeout` elapses.
    ///
    /// - Returns: `true` if idle, `false` if the timeout expired with work still pending.
    @objc(waitForIdleWithTimeout:)
    public func waitForIdle(timeout: TimeInterval) -> Bool {
        let pending = state.withLock { $0.pending }
        guard pending > 0 else { return true }

        let deadline: DispatchTime = timeout > 0 ? .now() + timeout : .now()
        return group.wait(timeout: deadline) == .success
    }
}

protocol ReplayRecoveryIdleGateProvider {
    var replayRecoveryIdleGate: SentryReplayRecoveryIdleGate { get }
}
