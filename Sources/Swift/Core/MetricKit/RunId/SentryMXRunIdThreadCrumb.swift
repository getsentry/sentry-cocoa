#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate

/// Spells the run ID into the call stack of a parked thread, so a MetricKit diagnostic that holds
/// the call stacks of all threads carries the run ID with it.
///
/// The thread stays parked for the rest of the process, which costs one idle thread. It is
/// parked once per process, so an SDK restart doesn't park a second one.
final class SentryMXRunIdThreadCrumb {
    private struct Parked {
        let runId: SentryCurrentRun.ID
        let addresses: [UInt64]
    }

    /// The crumb of the process. Every SDK start parks through it, so the process has one thread.
    static let shared = SentryMXRunIdThreadCrumb()

    private let parked = SentryMutex<Parked?>(nil)

    /// Parks the thread crumb spelling `runId`, or returns the crumb already parked for it.
    ///
    /// - Returns: The addresses of the spelled frames, outermost first, which the decoder matches
    ///   against the call stacks of a diagnostic. `nil` when the crumb couldn't be parked, or when
    ///   this process already parked a crumb for a different run ID.
    func park(runId: SentryCurrentRun.ID) -> [UInt64]? {
        parked.withLock { parked in
            if let parked {
                return parked.runId == runId ? parked.addresses : nil
            }
            guard let addresses = Self.spell(runId.rawValue) else {
                return nil
            }
            parked = Parked(runId: runId, addresses: addresses)
            return addresses
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
