#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)

import AVFoundation
import CoreGraphics
import Foundation
import UIKit

class SentryVideoFrameProcessor {
    private enum AppendFrameResult {
        case success
        case notReady
        case failure
    }

    /// Tolerance applied when mapping capture timestamps to presentation frame indices, to
    /// absorb floating-point error at frame boundaries.
    private static let frameIndexEpsilon = 0.000001

    let videoFrames: [SentryReplayFrame]
    let videoWriter: AVAssetWriter
    let currentPixelBuffer: SentryAppendablePixelBuffer
    let outputFileURL: URL
    let videoHeight: CGFloat
    let videoWidth: CGFloat
    let frameRate: Int
    let videoEnd: Date?

    var frameIndex: Int
    var lastImageSize: CGSize
    var usedFrames: [SentryReplayFrame]
    var isFinished: Bool
    private var outputFrameIndex: Int
    private var videoStart: Date?
    private var lastAppendedImage: UIImage?
    private var lastAppendedFrame: SentryReplayFrame?

    init(
        videoFrames: [SentryReplayFrame],
        videoWriter: AVAssetWriter,
        currentPixelBuffer: SentryAppendablePixelBuffer,
        outputFileURL: URL,
        videoHeight: CGFloat,
        videoWidth: CGFloat,
        frameRate: Int,
        initialFrameIndex: Int,
        initialImageSize: CGSize,
        videoEnd: Date? = nil
    ) {
        self.videoFrames = videoFrames
        self.videoWriter = videoWriter
        self.currentPixelBuffer = currentPixelBuffer
        self.outputFileURL = outputFileURL
        self.videoHeight = videoHeight
        self.videoWidth = videoWidth
        self.frameRate = frameRate
        self.videoEnd = videoEnd

        self.frameIndex = initialFrameIndex
        self.outputFrameIndex = 0
        self.lastImageSize = initialImageSize
        self.usedFrames = []
        self.isFinished = false
    }

    func processFrames(videoWriterInput: AVAssetWriterInput, onCompletion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void) {
        // Use the recommended loop pattern for AVAssetWriterInput
        // See https://developer.apple.com/documentation/avfoundation/avassetwriterinput/requestmediadatawhenready(on:using:)#Discussion
        // This could lead to an infinite loop if we don't make sure to mark the input as finished when the video is finished either by the end of the frames or by an error.
        while videoWriterInput.isReadyForMoreMediaData {
            SentrySDKLog.debug("[Session Replay] Video writer input is ready, status: \(videoWriter.status)")
            guard videoWriter.status == .writing else {
                SentrySDKLog.error("[Session Replay] Video writer is not writing anymore, cancelling the writing session, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                videoWriter.inputs.forEach { $0.markAsFinished() }
                videoWriter.cancelWriting()
                return onCompletion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            }
            guard frameIndex < videoFrames.count else {
                guard handleAppendResult(
                    appendLastFrameUntilVideoEnd(videoWriterInput: videoWriterInput),
                    onCompletion: onCompletion
                ) else { return }

                SentrySDKLog.debug("[Session Replay] No more frames available to process, finishing the video")
                return finishVideo(frameIndex: self.frameIndex, onCompletion: onCompletion)
            }

            guard processCurrentFrame(videoWriterInput: videoWriterInput, onCompletion: onCompletion) else { return }
        }
    }

    private func processCurrentFrame(
        videoWriterInput: AVAssetWriterInput,
        onCompletion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void
    ) -> Bool {
        let frame = videoFrames[frameIndex]
        guard let image = UIImage(contentsOfFile: frame.imagePath) else {
            return processUnreadableFrame(frame, videoWriterInput: videoWriterInput, onCompletion: onCompletion)
        }

        guard handleAppendResult(
            appendLastFrame(until: frame.time, videoWriterInput: videoWriterInput),
            onCompletion: onCompletion
        ) else { return false }

        SentrySDKLog.debug("[Session Replay] Image at index \(frameIndex) is ready, size: \(image.size)")
        guard lastImageSize == image.size else {
            SentrySDKLog.debug("[Session Replay] Image size has changed, finishing video")
            finishVideo(frameIndex: self.frameIndex, onCompletion: onCompletion)
            return false
        }
        lastImageSize = image.size

        guard handleAppendResult(
            append(image: image, forFrame: frame, videoWriterInput: videoWriterInput),
            onCompletion: onCompletion
        ) else { return false }

        frameIndex += 1
        return true
    }

    private func handleAppendResult(
        _ result: AppendFrameResult,
        onCompletion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void
    ) -> Bool {
        switch result {
        case .success:
            return true
        case .notReady:
            return false
        case .failure:
            cancelWriting(onCompletion: onCompletion)
            return false
        }
    }

    private func cancelWriting(onCompletion completion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void) {
        SentrySDKLog.error("[Session Replay] Failed to append image to pixel buffer, cancelling the writing session, reason: \(String(describing: videoWriter.error))")
        videoWriter.inputs.forEach { $0.markAsFinished() }
        videoWriter.cancelWriting()
        completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
    }

    private func appendLastFrameUntilVideoEnd(videoWriterInput: AVAssetWriterInput) -> AppendFrameResult {
        guard let videoEnd = videoEnd, let videoStart = videoStart else { return .success }
        return appendLastFrame(
            untilFrameIndex: presentationFrameCount(until: videoEnd, from: videoStart),
            videoWriterInput: videoWriterInput
        )
    }

    private func appendLastFrame(until date: Date, videoWriterInput: AVAssetWriterInput) -> AppendFrameResult {
        guard let videoStart = videoStart else { return .success }
        return appendLastFrame(
            untilFrameIndex: presentationFrameIndex(forCapturedFrameAt: date, from: videoStart),
            videoWriterInput: videoWriterInput
        )
    }

    private func appendLastFrame(untilFrameIndex targetFrameIndex: Int, videoWriterInput: AVAssetWriterInput) -> AppendFrameResult {
        guard let lastAppendedImage = lastAppendedImage,
            let lastAppendedFrame = lastAppendedFrame
        else { return .success }

        while outputFrameIndex < targetFrameIndex {
            switch append(image: lastAppendedImage, forFrame: lastAppendedFrame, videoWriterInput: videoWriterInput) {
            case .success:
                break
            case .notReady:
                return .notReady
            case .failure:
                return .failure
            }
        }

        return .success
    }

    private func append(image: UIImage, forFrame frame: SentryReplayFrame, videoWriterInput: AVAssetWriterInput) -> AppendFrameResult {
        guard videoWriterInput.isReadyForMoreMediaData else { return .notReady }

        if videoStart == nil {
            videoStart = frame.time
        }

        let presentTime = SentryOnDemandReplay.calculatePresentationTime(
            forFrameAtIndex: outputFrameIndex,
            frameRate: frameRate
        ).timeValue
        guard currentPixelBuffer.append(image: image, presentationTime: presentTime) else { return .failure }

        usedFrames.append(frame)
        lastAppendedImage = image
        lastAppendedFrame = frame
        outputFrameIndex += 1
        return .success
    }

    private func presentationFrameIndex(forCapturedFrameAt date: Date, from start: Date) -> Int {
        let elapsed = max(0, date.timeIntervalSince(start))
        let index = floor(elapsed * Double(frameRate) + Self.frameIndexEpsilon)
        return max(0, Int(index))
    }

    private func presentationFrameCount(until date: Date, from start: Date) -> Int {
        let elapsed = max(0, date.timeIntervalSince(start))
        let frameCount = ceil(elapsed * Double(frameRate) - Self.frameIndexEpsilon)
        return max(0, Int(frameCount))
    }

    // swiftlint:enable function_body_length cyclomatic_complexity
    func finishVideo(frameIndex: Int, onCompletion completion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void) {
        // Note: This method is expected to be called from the asset worker queue and *not* the processing queue.
        SentrySDKLog.info("[Session Replay] Finishing video with output file URL: \(outputFileURL), used frames count: \(usedFrames.count), video height: \(videoHeight), video width: \(videoWidth)")
        videoWriter.inputs.forEach { $0.markAsFinished() }
        videoWriter.finishWriting { [weak self] in
            guard let self = self else {
                SentrySDKLog.warning("[Session Replay] On-demand replay is deallocated, completing writing session without output video info")
                let videoResult = SentryRenderVideoResult(info: nil, finalFrameIndex: frameIndex)
                return completion(.success(videoResult))
            }
            SentrySDKLog.debug("[Session Replay] Finished video writing, status: \(self.videoWriter.status)")

            switch self.videoWriter.status {
            case .writing:
                SentrySDKLog.error("[Session Replay] Finish writing video was called with status writing, this is unexpected! Completing with no video info")
                let videoResult = SentryRenderVideoResult(info: nil, finalFrameIndex: frameIndex)
                return completion(.success(videoResult))
            case .cancelled:
                SentrySDKLog.warning("[Session Replay] Finish writing video was cancelled, completing with no video info.")
                let videoResult = SentryRenderVideoResult(info: nil, finalFrameIndex: frameIndex)
                return completion(.success(videoResult))
            case .completed:
                SentrySDKLog.debug("[Session Replay] Finish writing video was completed, creating video info from file attributes.")
                guard !self.usedFrames.isEmpty else {
                    SentrySDKLog.debug("[Session Replay] Finished video writing without appended frames, completing with no video info")
                    self.removeOutputFile()
                    let videoResult = SentryRenderVideoResult(info: nil, finalFrameIndex: frameIndex)
                    return completion(.success(videoResult))
                }

                do {
                    let videoInfo = try self.getVideoInfo(
                        from: self.outputFileURL,
                        usedFrames: self.usedFrames,
                        videoWidth: Int(self.videoWidth),
                        videoHeight: Int(self.videoHeight)
                    )
                    let videoResult = SentryRenderVideoResult(info: videoInfo, finalFrameIndex: frameIndex)
                    completion(.success(videoResult))
                } catch {
                    SentrySDKLog.warning("[Session Replay] Failed to create video info from file attributes, reason: \(error)")
                    completion(.failure(error))
                }
            case .failed:
                SentrySDKLog.warning("[Session Replay] Finish writing video failed, reason: \(String(describing: self.videoWriter.error))")
                completion(.failure(self.videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            case .unknown:
                SentrySDKLog.warning("[Session Replay] Finish writing video with unknown status, reason: \(String(describing: self.videoWriter.error))")
                completion(.failure(self.videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            @unknown default:
                SentrySDKLog.warning("[Session Replay] Finish writing video in unknown state, reason: \(String(describing: self.videoWriter.error))")
                completion(.failure(SentryOnDemandReplayError.errorRenderingVideo))
            }
        }
    }

    func getVideoInfo(from outputFileURL: URL, usedFrames: [SentryReplayFrame], videoWidth: Int, videoHeight: Int) throws -> SentryVideoInfo {
        SentrySDKLog.debug("[Session Replay] Getting video info from file: \(outputFileURL.path), width: \(videoWidth), height: \(videoHeight), used frames count: \(usedFrames.count)")
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
        guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
            SentrySDKLog.warning("[Session Replay] Failed to read video size from video file, reason: size attribute not found")
            throw SentryOnDemandReplayError.cantReadVideoSize
        }
        let minFrame = usedFrames.min(by: { $0.time < $1.time })
        guard let start = minFrame?.time else {
            // Note: This code path is currently not reached, because the `getVideoInfo` method is only called after the video is successfully created, therefore at least one frame was used.
            // The compiler still requires us to unwrap the optional value, and we do not permit force-unwrapping.
            SentrySDKLog.warning("[Session Replay] Failed to read video start time from used frames, reason: no frames found")
            throw SentryOnDemandReplayError.cantReadVideoStartTime
        }
        let duration = TimeInterval(usedFrames.count) / TimeInterval(self.frameRate)
        return SentryVideoInfo(
            path: outputFileURL,
            height: videoHeight,
            width: videoWidth,
            duration: duration,
            frameCount: usedFrames.count,
            frameRate: self.frameRate,
            start: start,
            end: start.addingTimeInterval(duration),
            fileSize: fileSize,
            screens: usedFrames.compactMap({ $0.screenName })
        )
    }
}

private extension SentryVideoFrameProcessor {
    func removeOutputFile() {
        guard FileManager.default.fileExists(atPath: outputFileURL.path) else { return }

        do {
            try FileManager.default.removeItem(at: outputFileURL)
            SentrySDKLog.debug("[Session Replay] Removed empty replay video at url: \(outputFileURL.path)")
        } catch {
            SentrySDKLog.warning("[Session Replay] Could not delete empty replay video at url: \(outputFileURL.path), reason: \(error)")
        }
    }

    func processUnreadableFrame(
        _ frame: SentryReplayFrame,
        videoWriterInput: AVAssetWriterInput,
        onCompletion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void
    ) -> Bool {
        if lastAppendedImage != nil {
            // Fill the gap left by the unreadable frame with the last appended image.
            guard handleAppendResult(
                appendLastFrame(until: frame.time, videoWriterInput: videoWriterInput),
                onCompletion: onCompletion
            ) else { return false }
        } else {
            SentrySDKLog.warning("[Session Replay] Could not load initial replay frame image, skipping frame.")
        }

        frameIndex += 1
        return true
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
