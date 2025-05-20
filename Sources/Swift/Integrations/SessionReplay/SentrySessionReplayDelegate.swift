import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate

@objc
protocol SentrySessionReplayDelegate: NSObjectProtocol {
    func sessionReplayShouldCaptureReplayForError() -> Bool
    func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL)
    func sessionReplayStarted(replayId: SentryId)
    func breadcrumbsForSessionReplay() -> [Breadcrumb]
    func currentScreenNameForSessionReplay() -> String?
}

#endif
