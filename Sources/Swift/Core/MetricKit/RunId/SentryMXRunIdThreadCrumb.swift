#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate

/// Spells the run ID into the call stack of a parked thread, so a MetricKit diagnostic that holds
/// the call stacks of all threads carries the run ID with it.
///
/// The thread stays parked for the rest of the process, which costs one idle thread. It is
/// parked once per process, so an SDK restart doesn't park a second one.
final class SentryMXRunIdThreadCrumb {
    private enum State {
        case notAttempted
        case parked(runId: SentryCurrentRun.ID, addresses: [UInt64])
        /// Parking was tried and didn't return the spelled frames. The thread may still exist,
        /// because parking gives up waiting for a thread that takes too long to spell, so it
        /// isn't tried again.
        case failed
    }

    /// The crumb of the process. Every SDK start parks through it, so the process has one thread.
    static let shared = SentryMXRunIdThreadCrumb()

    private let state = SentryMutex<State>(.notAttempted)

    /// Parks the thread crumb spelling `runId`, or returns the crumb already parked for it.
    ///
    /// Parking is tried once per instance, so a failed attempt, whose thread may still be parked,
    /// never leads to a second thread. The run of a failed attempt can't be matched, and its
    /// diagnostics are sent without a run ID.
    ///
    /// This waits for the crumb's thread to spell the run ID, so it must not be called on the
    /// main thread.
    ///
    /// - Returns: The addresses of the spelled frames, outermost first, which the decoder matches
    ///   against the call stacks of a diagnostic. `nil` when the crumb couldn't be parked, now or
    ///   in an earlier attempt, or when this process already parked a crumb for a different run
    ///   ID.
    func park(runId: SentryCurrentRun.ID) -> [UInt64]? {
        state.withLock { state in
            switch state {
            case let .parked(parkedRunId, addresses):
                return parkedRunId == runId ? addresses : nil
            case .failed:
                return nil
            case .notAttempted:
                guard let addresses = Self.spell(runId.rawValue) else {
                    SentrySDKLog.warning("Could not park the thread crumb for the run ID, so MetricKit diagnostics of this run can't be matched to it.")
                    state = .failed
                    return nil
                }
                state = .parked(runId: runId, addresses: addresses)
                return addresses
            }
        }
    }

    /// Parks a new thread spelling `message`, without the once-per-process guard.
    static func spell(_ message: String) -> [UInt64]? {
        var addresses = [UInt64](repeating: 0, count: Int(SENTRY_THREADCRUMB_MAX_LENGTH))
        let count = addresses.withUnsafeMutableBufferPointer { buffer -> Int in
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            return sentry_threadcrumb_park(message, baseAddress, buffer.count)
        }
        guard count > 0 else {
            return nil
        }
        return Array(addresses.prefix(count))
    }
}
#endif
