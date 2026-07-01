import Darwin.POSIX.dlfcn

struct SentryProfilingSampleAccumulator {
    private struct FrameKey: Hashable {
        let instructionAddress: String?
        let function: String?
        let module: String?
        let package: String?
        let imageAddress: String?
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
                    name: resolveThreadName(thread, threadId: threadId),
                    priority: 0
                )
            }

            let frameIndices = deduplicateFrames(from: thread.stacktrace)
            // SentryStacktrace orders frames caller-to-callee (root-first),
            // but profile V2 format expects leaf-first (matching the continuous profiler).
            let stackIdx = deduplicateStack(Array(frameIndices.reversed()))

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

    private func resolveThreadName(_ thread: SentryThread, threadId: UInt64) -> String {
        if let threadName = thread.name, !threadName.isEmpty {
            return threadName
        }
        if thread.isMain?.boolValue == true {
            return "main"
        }
        return "Thread \(threadId)"
    }

    private mutating func deduplicateFrames(from stacktrace: SentryStacktrace?) -> [Int] {
        guard let stacktrace else { return [] }
        var indices: [Int] = []
        for frame in stacktrace.frames {
            let function = frame.function ?? resolveSymbolName(for: frame.instructionAddress)
            let key = FrameKey(
                instructionAddress: frame.instructionAddress,
                function: function,
                module: frame.module,
                package: frame.package,
                imageAddress: frame.imageAddress
            )
            if let existing = frameIndex[key] {
                indices.append(existing)
            } else {
                let idx = frames.count
                frameIndex[key] = idx
                frames.append(.init(
                    instructionAddress: frame.instructionAddress,
                    function: function,
                    module: frame.module,
                    package: frame.package,
                    imageAddress: frame.imageAddress,
                    inApp: frame.inApp?.boolValue
                ))
                indices.append(idx)
            }
        }
        return indices
    }

    private func resolveSymbolName(for instructionAddress: String?) -> String? {
        guard let addressStr = instructionAddress,
              addressStr.hasPrefix("0x"),
              let addr = UInt(addressStr.dropFirst(2), radix: 16),
              addr != 0 else { return nil }
        var info = Dl_info()
        guard dladdr(UnsafeRawPointer(bitPattern: addr), &info) != 0,
              let sname = info.dli_sname else { return nil }
        return String(cString: sname)
    }

    private mutating func deduplicateStack(_ frameIndices: [Int]) -> Int {
        if let existing = stackIndex[frameIndices] {
            return existing
        }
        let idx = stacks.count
        stackIndex[frameIndices] = idx
        stacks.append(frameIndices)
        return idx
    }
}
