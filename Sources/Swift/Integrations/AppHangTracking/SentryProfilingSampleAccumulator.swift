struct SentryProfilingSampleAccumulator {
    private struct FrameKey: Hashable {
        let instructionAddress: String?
        let function: String?
        let module: String?
    }

    private var frameIndex: [FrameKey: Int] = [:]
    private var frames: [SentryAppHang.ProfilingData.Frame] = []
    private var stackIndex: [[Int]: Int] = [:]
    private var stacks: [[Int]] = []
    private var samples: [SentryAppHang.ProfilingData.Sample] = []
    private var threadMetadata: [String: SentryAppHang.ProfilingData.ThreadMetadata] = [:]

    mutating func appendSample(from threads: [SentryThread], timestamp: TimeInterval) {
        for thread in threads {
            let threadId = thread.threadId?.uint64Value ?? 0
            let threadIdStr = "\(threadId)"

            if threadMetadata[threadIdStr] == nil {
                threadMetadata[threadIdStr] = .init(
                    name: thread.name ?? "Thread \(threadId)",
                    priority: 0
                )
            }

            var frameIndices: [Int] = []
            if let stacktrace = thread.stacktrace {
                for frame in stacktrace.frames {
                    let key = FrameKey(
                        instructionAddress: frame.instructionAddress,
                        function: frame.function,
                        module: frame.module
                    )
                    let idx: Int
                    if let existing = frameIndex[key] {
                        idx = existing
                    } else {
                        idx = frames.count
                        frameIndex[key] = idx
                        frames.append(.init(
                            instructionAddress: frame.instructionAddress,
                            function: frame.function,
                            module: frame.module
                        ))
                    }
                    frameIndices.append(idx)
                }
            }

            let stackIdx: Int
            if let existing = stackIndex[frameIndices] {
                stackIdx = existing
            } else {
                stackIdx = stacks.count
                stackIndex[frameIndices] = stackIdx
                stacks.append(frameIndices)
            }

            samples.append(.init(
                timestamp: timestamp,
                stackIndex: stackIdx,
                threadId: threadId
            ))
        }
    }

    func toProfilingData() -> SentryAppHang.ProfilingData {
        SentryAppHang.ProfilingData(
            frames: frames,
            stacks: stacks,
            samples: samples,
            threadMetadata: threadMetadata
        )
    }
}
