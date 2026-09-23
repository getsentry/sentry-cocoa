import Foundation

/// Asserts that KSCrash `didWriteReport` persisted the session-replay recovery checkpoint.
///
/// The scenario seeds sync state through the SDK `SENTRY_CRASH_E2E` hook. This asserter
/// verifies the on-disk checkpoint before the drain launch:
///
/// - `<cacheDir>/crash-e2e-replay-checkpoint` — segment id, last segment end, replay type
enum CrashTimeReplayAsserter {
    private static let fileName = "crash-e2e-replay-checkpoint"
    private static let expectedSegmentId: UInt32 = 7
    private static let expectedLastSegmentEnd: Double = 123.5
    private static let expectedReplayType: UInt32 = 1

    static func assertCheckpointIfNeeded(scenario: Scenario, cacheDirectory: URL, platform: String) throws {
        switch scenario {
        case .crashTimeReplay, .crashTimeReplayAttachmentCrash:
            try assert(cacheDirectory: cacheDirectory, platform: platform, scenario: scenario)
        default:
            return
        }
    }

    static func assert(cacheDirectory: URL, platform: String, scenario: Scenario = .crashTimeReplay) throws {
        let url = cacheDirectory.appendingPathComponent(fileName)
        let label = "\(platform)/\(scenario.rawValue)"
        guard FileManager.default.fileExists(atPath: url.path) else {
            try fail(
                "Expected replay recovery checkpoint at \(url.path) for \(label)"
            )
        }

        let data = try Data(contentsOf: url)
        let segmentSize = MemoryLayout<UInt32>.size
        let timestampSize = MemoryLayout<Double>.size
        let typeSize = MemoryLayout<UInt32>.size
        let expectedSize = segmentSize + timestampSize + typeSize
        guard data.count >= expectedSize else {
            try fail(
                "Replay checkpoint is too small for \(label): \(data.count) bytes at \(url.path)"
            )
        }

        let segmentId: UInt32 = readValue(from: data, at: 0)
        let lastSegmentEnd: Double = readValue(from: data, at: segmentSize)
        let replayType: UInt32 = readValue(from: data, at: segmentSize + timestampSize)

        guard segmentId == expectedSegmentId else {
            try fail(
                "Expected replay checkpoint segmentId \(expectedSegmentId) for \(label), found \(segmentId)"
            )
        }
        guard lastSegmentEnd == expectedLastSegmentEnd else {
            try fail(
                "Expected replay checkpoint lastSegmentEnd \(expectedLastSegmentEnd) for \(label), found \(lastSegmentEnd)"
            )
        }
        guard replayType == expectedReplayType else {
            try fail(
                "Expected replay checkpoint replayType \(expectedReplayType) for \(label), found \(replayType)"
            )
        }

        log("✅ \(label) checkpoint assertions passed.")
    }

    private static func readValue<T>(from data: Data, at offset: Int) -> T {
        data.subdata(in: offset..<(offset + MemoryLayout<T>.size)).withUnsafeBytes { raw in
            raw.load(as: T.self)
        }
    }
}
