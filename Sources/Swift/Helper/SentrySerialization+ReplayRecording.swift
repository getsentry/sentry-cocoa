@_implementationOnly import _SentryPrivate

extension SentryReplayRecording {
    @objc public func data() -> Data? {
        var recording = Data()
        guard let headerData = SentrySerialization.data(withJSONObject: headerForReplayRecording()) else {
            SentrySDKLog.error("Failed to serialize replay recording header.")
            return nil
        }
        recording.append(headerData)
        let newLineData = Data(bytes: "\n", count: 1)
        recording.append(newLineData)
        guard let replayData = SentrySerialization.data(withJSONObject: serialize()) else {
            SentrySDKLog.error("Failed to serialize replay recording data.")
            return nil
        }
        recording.append(replayData)
        return recording
    }
}
