@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import Foundation

/// Configuration for recovering a previous session replay after a crash or app restart.
private struct PreviousReplayConfig {
    let type: SentryReplayType
    let duration: TimeInterval
    let segmentId: Int
    let beginning: Date
}

/// Handles recovery of session replay from previous app sessions, including crash replays.
struct SessionReplayRecovery {
    
    private let replayOptions: SentryReplayOptions
    private let random: SentryRandomProtocol
    private let replayProcessingQueue: SentryDispatchQueueWrapper
    private let replayAssetWorkerQueue: SentryDispatchQueueWrapper
    private let replayFileManager: SessionReplayFileManager
    
    init(
        replayOptions: SentryReplayOptions,
        random: SentryRandomProtocol,
        replayProcessingQueue: SentryDispatchQueueWrapper,
        replayAssetWorkerQueue: SentryDispatchQueueWrapper,
        replayFileManager: SessionReplayFileManager
    ) {
        self.replayOptions = replayOptions
        self.random = random
        self.replayProcessingQueue = replayProcessingQueue
        self.replayAssetWorkerQueue = replayAssetWorkerQueue
        self.replayFileManager = replayFileManager
    }
    
    // MARK: - Recovery

    /// Send the cached frames from a previous session that eventually crashed.
    ///
    /// This function is called when processing an event created by SentryCrashIntegration,
    /// which runs in the background. That's why we don't need to dispatch the generation of the
    /// replay to the background in this function.
    func resumePreviousSessionReplay(_ event: Event) {
        SentrySDKLog.debug("[Session Replay] Resuming previous session replay")
        guard let dir = replayFileManager.replayDirectory(),
              let jsonObject = replayFileManager.lastReplayInfo() else {
            SentrySDKLog.debug("[Session Replay] No last replay info found, not resuming previous session replay")
            return
        }

        let replayId = parseReplayId(from: jsonObject)
        
        guard let path = jsonObject["path"] as? String else {
            SentrySDKLog.error("[Session Replay] Failed to read path from last replay")
            return
        }

        let lastReplayURL = dir.appendingPathComponent(path)
        
        guard let previousReplayConfig = loadPreviousReplayConfig(from: lastReplayURL, jsonObject: jsonObject) else {
            return
        }
        
        createAndSendPreviousReplayVideos(
            replayId: replayId,
            lastReplayURL: lastReplayURL,
            config: previousReplayConfig,
            event: event
        )

        do {
            try FileManager.default.removeItem(at: lastReplayURL)
            SentrySDKLog.debug("[Session Replay] Deleted last replay file at path: \(lastReplayURL)")
        } catch {
            SentrySDKLog.warning("[Session Replay] Could not delete last replay file at path: \(lastReplayURL), error : \(error.localizedDescription)")
        }
    }
    
    // MARK: - Parsing
    
    private func parseReplayId(from jsonObject: [String: Any]) -> SentryId {
        if let replayIdString = jsonObject["replayId"] as? String {
            return SentryId(uuidString: replayIdString)
        }
        return SentryId()
    }
    
    // MARK: - Configuration Loading
    
    private func loadPreviousReplayConfig(
        from lastReplayURL: URL,
        jsonObject: [String: Any]
    ) -> PreviousReplayConfig? {
        var crashInfo = SentryCrashReplay()
        let crashInfoPath = lastReplayURL.appendingPathComponent("crashInfo").path
        let hasCrashInfo = sentrySessionReplaySync_readInfo(&crashInfo, crashInfoPath)

        let type: SentryReplayType = hasCrashInfo ? .session : .buffer
        let duration = hasCrashInfo ? replayOptions.sessionSegmentDuration : replayOptions.errorReplayDuration
        let segmentId = hasCrashInfo ? Int(crashInfo.segmentId) + 1 : 0

        if type == .buffer {
            SentrySDKLog.debug("[Session Replay] Previous session replay is a buffer, using error sample rate")
            let errorSampleRate = (jsonObject["errorSampleRate"] as? NSNumber)?.doubleValue ?? 0
            if random.nextNumber() >= errorSampleRate {
                SentrySDKLog.info("[Session Replay] Buffer session replay event not sampled, dropping replay")
                return nil
            }
        }

        let resumeReplayMaker = createResumeReplayMaker(from: lastReplayURL)
        
        let beginning: Date
        if hasCrashInfo {
            beginning = Date(timeIntervalSinceReferenceDate: crashInfo.lastSegmentEnd)
        } else {
            guard let oldestFrame = resumeReplayMaker.oldestFrameDate else {
                SentrySDKLog.debug("[Session Replay] No frames to send, dropping replay")
                return nil
            }
            beginning = oldestFrame
        }
        
        return PreviousReplayConfig(
            type: type,
            duration: duration,
            segmentId: segmentId,
            beginning: beginning
        )
    }
    
    // MARK: - Replay Maker
    
    private func createResumeReplayMaker(from lastReplayURL: URL) -> SentryOnDemandReplay {
        let resumeReplayMaker = SentryOnDemandReplay(
            withContentFrom: lastReplayURL.path,
            processingQueue: replayProcessingQueue,
            assetWorkerQueue: replayAssetWorkerQueue
        )
        resumeReplayMaker.bitRate = replayOptions.replayBitRate
        resumeReplayMaker.videoScale = replayOptions.sizeScale
        resumeReplayMaker.frameRate = Int(replayOptions.frameRate)
        return resumeReplayMaker
    }
    
    // MARK: - Video Creation and Sending
    
    private func createAndSendPreviousReplayVideos(
        replayId: SentryId,
        lastReplayURL: URL,
        config: PreviousReplayConfig,
        event: Event
    ) {
        let resumeReplayMaker = createResumeReplayMaker(from: lastReplayURL)
        let end = config.beginning.addingTimeInterval(config.duration)
        let videos = resumeReplayMaker.createVideoWith(beginning: config.beginning, end: end)

        SentrySDKLog.debug("[Session Replay] Created replay with \(videos.count) video segments")

        guard !videos.isEmpty else {
            SentrySDKLog.error("[Session Replay] Could not create replay video, reason: no videos available")
            return
        }

        // For each segment we need to create a new event with the video.
        var currentSegmentId = config.segmentId
        var currentType = config.type
        for video in videos {
            captureVideo(video, replayId: replayId, segmentId: currentSegmentId, type: currentType)
            currentSegmentId += 1
            // type buffer is only for the first segment
            currentType = .session
        }

        var eventContext = event.context ?? [:]
        eventContext["replay"] = ["replay_id": replayId.sentryIdString]
        event.context = eventContext
    }

    private func captureVideo(_ video: SentryVideoInfo, replayId: SentryId, segmentId: Int, type: SentryReplayType) {
        let replayEvent = SentryReplayEvent(
            eventId: replayId,
            replayStartTimestamp: video.start,
            replayType: type,
            segmentId: segmentId
        )
        replayEvent.timestamp = video.end

        let recording = SentryReplayRecording(
            segmentId: segmentId,
            video: video,
            extraEvents: []
        )

        SentrySDKInternal.currentHub().captureReplayEvent(
            replayEvent,
            replayRecording: recording,
            video: video.path
        )

        do {
            try FileManager.default.removeItem(at: video.path)
        } catch {
            SentrySDKLog.warning("[Session Replay] Could not delete replay segment from disk: \(error.localizedDescription)")
        }
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
