// swiftlint:disable missing_docs
import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

@objc
@_spi(Private) public protocol SentrySessionReplayDelegate: NSObjectProtocol {
    func sessionReplayShouldCaptureReplayForError() -> Bool
    func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL)
    func sessionReplayStarted(replayId: SentryId)
    func sessionReplayEnded()
    func breadcrumbsForSessionReplay() -> [Breadcrumb]
    func currentScreenNameForSessionReplay() -> String?
}

#endif
// swiftlint:enable missing_docs
