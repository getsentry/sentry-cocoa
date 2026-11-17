#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

import Foundation

/// Tells ``SentryFramesTracker`` what happens to the frames of the app. The tracker turns this into
/// slow and frozen frames, frames delay, and callbacks for its listeners, and doesn't know how the
/// frames are observed.
///
/// - Warning: Except for `totalFrames`, all members must be used on the main thread.
protocol SentryFrameSource: AnyObject {
    /// The source references the delegate weakly.
    func start(delegate: SentryFrameSourceDelegate)
    func stop()

    /// The number of frames while the source was started, about one per refresh of the display. Can
    /// be called on any thread.
    func totalFrames() -> UInt

    /// Starts counting the total frames from zero.
    func resetFrames()
}

/// All methods are called on the main thread.
protocol SentryFrameSourceDelegate: AnyObject {
    /// Called before the other methods report a frame that has this frame rate.
    func frameSource(didMeasureFrameRate frameRate: UInt64, at systemTimestamp: UInt64)

    /// The main thread was free to produce a frame at the timestamp. If it gets blocked from now on,
    /// the frame that is in flight since this timestamp is the one that is delayed.
    func frameSource(didStartFrameAt systemTimestamp: UInt64)

    /// A frame took longer than the slow frame threshold of the current frame rate. The end of the
    /// delayed frame is also the start of the next one.
    func frameSource(didDelayFrameFrom startSystemTimestamp: UInt64, to endSystemTimestamp: UInt64, duration: CFTimeInterval)

    /// The app produced a new frame.
    func frameSourceDidRenderFrame()
}

#endif
