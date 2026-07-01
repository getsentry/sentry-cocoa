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
            let package: String?
            let imageAddress: String?
            let inApp: Bool?

            init(
                instructionAddress: String?,
                function: String?,
                module: String?,
                package: String? = nil,
                imageAddress: String? = nil,
                inApp: Bool? = nil
            ) {
                self.instructionAddress = instructionAddress
                self.function = function
                self.module = module
                self.package = package
                self.imageAddress = imageAddress
                self.inApp = inApp
            }
        }

        struct Sample {
            let timestamp: TimeInterval
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

    let profilerId: SentryId?
    let profilingData: ProfilingData?
    let startSystemTime: UInt64
    let endSystemTime: UInt64

    init(duration: TimeInterval, state: State, profilerId: SentryId? = nil, profilingData: ProfilingData? = nil, startSystemTime: UInt64 = 0, endSystemTime: UInt64 = 0) {
        self.duration = duration
        self.state = state
        self.profilerId = profilerId
        self.profilingData = profilingData
        self.startSystemTime = startSystemTime
        self.endSystemTime = endSystemTime
    }
}
