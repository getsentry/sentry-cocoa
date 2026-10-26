internal import _SentryPrivate
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))
import UIKit

/// API for controlling Session Replay.
///
/// Replay lifecycle methods may be called from any thread. They return before the requested
/// operation completes and execute serially in call order.
@objc(SentryReplayApi)
@objcMembers
open class SentryReplayApi: NSObject {

    /// Creates a session replay API.
    ///
    /// The SDK exposes one shared instance through ``SentrySDK/replay``.
    override public init() {
        super.init()
    }

    /// Marks this view to be masked during replays.
    open func maskView(_ view: UIView) {
        SentryRedactViewHelper.maskView(view)
    }

    /// Marks this view to not be masked during the redact step of session replay.
    open func unmaskView(_ view: UIView) {
        SentryRedactViewHelper.unmaskView(view)
    }

    /// Pauses the current replay until ``resume()`` is called.
    ///
    /// Automatically started replays remain paused within the same process.
    open func pause() {
        SentrySDKLog.info("[Session Replay] Pausing session")
        dispatchReplayCommand { replayIntegration in
            replayIntegration.pause()
        }
    }

    /// Resumes a replay paused with ``pause()``.
    open func resume() {
        SentrySDKLog.info("[Session Replay] Resuming session")
        dispatchReplayCommand { replayIntegration in
            replayIntegration.resume()
        }
    }

    /// Starts a new replay session. Does nothing if a replay is already active.
    ///
    /// This explicit start bypasses session sampling. Recording and delivery remain subject to
    /// active Replay rate limits.
    open func start() {
        SentrySDKLog.info("[Session Replay] Starting session")
        dispatchReplayCommand { replayIntegration in
            replayIntegration.start()
        }
    }

    /// Starts Replay in buffer mode. Does nothing if a replay is already active.
    ///
    /// The rolling buffer is sent when ``flush()`` is called or when an error is captured and
    /// selected by the configured error sample rate. This explicit start bypasses session sampling.
    open func startBuffering() {
        SentrySDKLog.info("[Session Replay] Starting buffer")
        dispatchReplayCommand { replayIntegration in
            replayIntegration.startBuffering()
        }
    }

    /// Sends buffered replay data to Sentry and continues recording in session mode.
    ///
    /// If Replay is inactive, starts a new replay session. This explicit operation bypasses error
    /// sampling.
    open func flush() {
        SentrySDKLog.info("[Session Replay] Flushing session")
        dispatchReplayCommand { replayIntegration in
            replayIntegration.flush()
        }
    }

    /// Stops the current replay.
    ///
    /// A subsequent ``start()`` or ``startBuffering()`` call creates a new replay.
    open func stop() {
        SentrySDKLog.info("[Session Replay] Stopping session")
        dispatchReplayCommand { replayIntegration in
            replayIntegration.stop()
        }
    }

    /// Shows an overlay on the app to debug session replay masking.
    ///
    /// By calling this function an overlay will appear covering the parts of the app that will be
    /// masked for the session replay. This will only work if the debugger is attached and it will
    /// cause some slow frames.
    ///
    /// - Note: This method must be called from the main thread.
    /// - Warning: This is an experimental feature and may still have bugs. Do not use this in
    ///   production.
    open func showMaskPreview() {
        SentrySDKLog.debug("[Session Replay] Showing mask preview")
        showMaskPreview(1)
    }

    /// Shows an overlay on the app to debug session replay masking.
    ///
    /// By calling this function an overlay will appear covering the parts of the app that will be
    /// masked for the session replay. This will only work if the debugger is attached and it will
    /// cause some slow frames.
    ///
    /// - Parameter opacity: The opacity of the overlay.
    /// - Note: This method must be called from the main thread.
    /// - Warning: This is an experimental feature and may still have bugs. Do not use this in
    ///   production.
    open func showMaskPreview(_ opacity: CGFloat) {
        SentrySDKLog.debug("[Session Replay] Showing mask preview with opacity: \(opacity)")
        installedReplayIntegration()?.showMaskPreview(Float(opacity))
    }

    /// Removes the overlay that shows replay masking.
    ///
    /// - Note: This method must be called from the main thread.
    /// - Warning: This is an experimental feature and may still have bugs. Do not use this in
    ///   production.
    open func hideMaskPreview() {
        SentrySDKLog.debug("[Session Replay] Hiding mask preview")
        installedReplayIntegration()?.hideMaskPreview()
    }

    private func dispatchReplayCommand(_ command: @escaping (SentrySessionReplayIntegration) -> Void) {
        DispatchQueue.main.async { [self] in
            guard let replayIntegration = self.installedReplayIntegration() else {
                SentrySDKLog.warning(
                    "[Session Replay] Cannot execute command because the Session Replay integration is not installed."
                )
                return
            }
            command(replayIntegration)
        }
    }

    private func installedReplayIntegration() -> SentrySessionReplayIntegration? {
        SentrySDKInternal.currentHub().getInstalledIntegration(SentrySessionReplayIntegration.self)
            as? SentrySessionReplayIntegration
    }
}
#endif
