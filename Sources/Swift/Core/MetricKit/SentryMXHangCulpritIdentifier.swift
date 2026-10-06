#if os(iOS) || os(macOS) || os(visionOS)

/// Selects a representative root-to-frame path using Android's ANR frequency/depth/quality score.
struct SentryMXHangCulpritIdentifier {
    private let inAppLogic: SentryInAppLogic

    init(inAppLogic: SentryInAppLogic) {
        self.inAppLogic = inAppLogic
    }

    func identify(in tree: SentryMXCallStackTree) -> SentryStacktrace? {
        // Use the same first stack as the existing hang event. An attributed
        // MetricKit stack is not necessarily the main thread, so do not prefer it here.
        guard let samples = tree.callStacks.first?.validatedHangSamples() else { return nil }
        var candidates = [[String]: (frames: [MXSample.MXFrame], count: Double)]()
        for sample in samples where sample.count > 0 && sample.frames.count >= 2 {
            for depth in 1...sample.frames.count {
                let frames = Array(sample.frames.prefix(depth))
                let key = frames.map { frame in
                    if let uuid = frame.binaryUUID, frame.offsetIntoBinaryTextSegment >= 0 {
                        return "\(uuid.uuidString):\(frame.offsetIntoBinaryTextSegment)"
                    }
                    return "\(frame.binaryName ?? "unknown"):\(frame.address)"
                }
                if let existing = candidates[key] {
                    candidates[key] = (existing.frames, existing.count + Double(sample.count))
                } else {
                    candidates[key] = (frames, Double(sample.count))
                }
            }
        }

        var bestFrames: [MXSample.MXFrame]?
        var bestKey = [String]()
        var bestScore = -Double.infinity
        for (key, candidate) in candidates {
            // Missing binary metadata is not evidence of application code (it can be a kernel frame).
            let appFrames = candidate.frames.filter { inAppLogic.is(inApp: $0.binaryName) }.count
            let score = candidate.count * Double(candidate.frames.count + appFrames)
            // Android leaves ties unspecified. Make selection reproducible across dictionary
            // iteration order and ASLR by comparing image-relative path identities.
            if score > bestScore || (score == bestScore && key.lexicographicallyPrecedes(bestKey)) {
                bestScore = score
                bestKey = key
                bestFrames = candidate.frames
            }
        }
        guard let bestFrames else { return nil }
        let frames = bestFrames.map { mxFrame in
            let frame = mxFrame.toSentryFrame()
            frame.inApp = NSNumber(value: inAppLogic.is(inApp: mxFrame.binaryName))
            return frame
        }
        return SentryStacktrace(frames: frames, registers: [:])
    }

}

#endif
