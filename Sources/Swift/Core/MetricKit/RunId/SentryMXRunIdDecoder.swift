#if os(iOS) || os(macOS) || os(visionOS)

/// Finds the run ID a MetricKit diagnostic belongs to.
protocol SentryMXRunIdDecoding {
    /// - Returns: The run ID of the run whose thread crumb the call stacks contain, or `nil` when
    ///   they contain none the SDK recorded.
    func runId(of callStackTree: SentryMXCallStackTree) -> String?
}

/// Finds the run ID by the thread crumb: a thread whose frames spell a run ID the SDK recorded.
///
/// The decoder matches the frame addresses of the recorded crumbs against the call stacks, so it
/// needs no symbolication. It looks for the crumb's frames anywhere in a call stack instead of at
/// a fixed depth, so frames the OS adds above or below the crumb don't hide it.
struct SentryMXRunIdDecoder: SentryMXRunIdDecoding {
    let store: SentryMXRunIdRecordStore

    func runId(of callStackTree: SentryMXCallStackTree) -> String? {
        var recordsByFirstAddress: [UInt64: [SentryMXRunIdRecord]] = [:]
        for record in store.records() {
            guard let first = record.threadCrumbAddresses.first else {
                continue
            }
            recordsByFirstAddress[first, default: []].append(record)
        }
        guard !recordsByFirstAddress.isEmpty else {
            return nil
        }

        for callStack in callStackTree.callStacks {
            for frame in callStack.callStackRootFrames {
                if let runId = runId(startingAt: frame, recordsByFirstAddress: recordsByFirstAddress) {
                    return runId
                }
            }
        }
        return nil
    }

    private func runId(startingAt frame: SentryMXFrame, recordsByFirstAddress: [UInt64: [SentryMXRunIdRecord]]) -> String? {
        if let candidates = recordsByFirstAddress[frame.address] {
            for candidate in candidates where spells(candidate.threadCrumbAddresses, from: frame, index: 0) {
                return candidate.runId
            }
        }
        for subFrame in frame.subFrames ?? [] {
            if let runId = runId(startingAt: subFrame, recordsByFirstAddress: recordsByFirstAddress) {
                return runId
            }
        }
        return nil
    }

    /// Whether the frames from `frame` inwards have the given addresses, in order.
    private func spells(_ addresses: [UInt64], from frame: SentryMXFrame, index: Int) -> Bool {
        guard index < addresses.count, frame.address == addresses[index] else {
            return false
        }
        if index == addresses.count - 1 {
            return true
        }
        return (frame.subFrames ?? []).contains { spells(addresses, from: $0, index: index + 1) }
    }
}
#endif
