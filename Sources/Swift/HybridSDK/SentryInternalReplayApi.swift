// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides session replay access for hybrid SDKs.
public struct SentryInternalReplayApi {

    typealias Dependencies = HubProvider & ReplayIntegrationProviderProvider

    private let hub: Hub
    private let replayIntegrationProvider: ReplayIntegrationProvider

    init(dependencies: Dependencies) {
        self.hub = dependencies.hub
        self.replayIntegrationProvider = dependencies.replayIntegrationProvider
    }

    /// Starts a new replay session if Replay is inactive.
    public func start() {
        SentrySDK.replay.start()
    }

    /// Starts Replay in buffer mode if Replay is inactive.
    public func startBuffering() {
        SentrySDK.replay.startBuffering()
    }

    /// Pauses the current replay.
    public func pause() {
        SentrySDK.replay.pause()
    }

    /// Resumes a replay paused with ``pause()``.
    public func resume() {
        SentrySDK.replay.resume()
    }

    /// Flushes buffered replay data or starts a new replay session if Replay is inactive.
    public func flush() {
        SentrySDK.replay.flush()
    }

    /// Stops the current replay.
    public func stop() {
        SentrySDK.replay.stop()
    }

    /// Configures the session replay with a custom breadcrumb converter
    /// and/or screenshot provider.
    @_spi(Private)
    public func configure(
        breadcrumbConverter: SentryReplayBreadcrumbConverter?,
        screenshotProvider: SentryViewScreenshotProvider?
    ) {
        replayIntegrationProvider.getReplayIntegration()?.configureReplayWith(
            breadcrumbConverter,
            screenshotProvider: screenshotProvider
        )
    }

    /// Captures a replay event. Returns `true` if the replay was captured.
    @discardableResult
    public func capture() -> Bool {
        replayIntegrationProvider.getReplayIntegration()?.captureReplay() ?? false
    }

    /// The current replay ID, or `nil` if no replay is active.
    public var replayId: String? {
        var result: String?
        hub.configureScope { scope in
            result = scope.replayId
        }
        // The scope's `replayId` is only set once a replay is sent. While a
        // buffer (on-error) replay is recording it stays nil, so fall back to
        // the id assigned when recording started.
        if result == nil {
            result = hub.getSessionReplayId()
        }
        return result
    }

    /// Adds classes to the replay ignore list.
    public func addIgnoreClasses(_ classes: [AnyClass]) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.addIgnoreClasses(classes: classes)
    }

    /// Adds classes to the replay redact list.
    public func addRedactClasses(_ classes: [AnyClass]) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.addRedactClasses(classes: classes)
    }

    /// Sets the container class whose subviews are ignored during replay.
    public func setIgnoreContainerClass(_ containerClass: AnyClass) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.setIgnoreContainerClass(containerClass)
    }

    /// Sets the container class whose subviews are redacted during replay.
    public func setRedactContainerClass(_ containerClass: AnyClass) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.setRedactContainerClass(containerClass)
    }

    /// Sets tags on the current replay session.
    public func setTags(_ tags: [String: Any]) {
        replayIntegrationProvider.getReplayIntegration()?.setReplayTags(tags)
    }

    /// Registers a trace ID with the current replay segment.
    ///
    /// The trace ID is a 32-character hexadecimal string. It is added to the
    /// `trace_ids` of the next replay segment sent, in both session and buffer
    /// (on-error) modes. Malformed strings and duplicates are ignored, and at most
    /// 100 IDs are kept per segment.
    ///
    /// Safe to call from any thread. When Session Replay is disabled or not
    /// recording, this is a no-op.
    ///
    /// Introduced in cocoa 9.30.0 for hybrid SDKs (React Native, Flutter) that hold
    /// the trace ID as a hex string. Name and semantics are stable once released.
    public func registerTraceId(_ traceId: String) {
        replayIntegrationProvider.getReplayIntegration()?.registerReplayTraceId(traceId)
    }
}

#endif
// swiftlint:enable missing_docs
