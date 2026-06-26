@_implementationOnly import _SentryPrivate

/// A hang event derived from a run loop delay that exceeded an observer's threshold.
struct SentryAppHang {
    enum State {
        case started
        case ended
    }

    struct ProfilingData {
        struct Frame {
            let instructionAddress: String?
            let function: String?
            let module: String?
        }

        struct Sample {
            let absoluteTimestamp: UInt64
            let stackIndex: Int
            let threadId: UInt64
        }

        struct ThreadMetadata {
            let name: String
            let priority: Int
        }

        let frames: [Frame]
        let stacks: [[Int]]
        let samples: [Sample]
        let threadMetadata: [String: ThreadMetadata]
    }

    let duration: TimeInterval
    let state: State

    /// The profiler session ID for linking the hang event to its profile chunk.
    /// Set when continuous profiling is active or when custom sampling produced data.
    let profilerId: SentryId?

    /// Captured profile samples from custom main-thread sampling.
    /// nil when continuous profiling handled the data, or when profiling is disabled.
    let profilingData: ProfilingData?

    /// Mach absolute time when the hang started.
    let startSystemTime: UInt64

    /// Mach absolute time when the hang ended (or current time for .started state).
    let endSystemTime: UInt64
}
