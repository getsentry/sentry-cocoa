@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT

// This class should be final but we are subclassing it in tests
// Also, this class will be deprecated once SessionReplayIntegration
// is no longer used from Objective C
@_spi(Private) @objc
public class SentrySessionReplayIntegrationObjC: NSObject, SwiftIntegration {
    private let integration: SentrySessionReplayIntegration<SentryDependencyContainer>
    
    @objc
    public required init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard let integration = SentrySessionReplayIntegration<SentryDependencyContainer>(with: options, dependencies: dependencies) else {
            return nil
        }
        self.integration = integration
    }
    
    @objc(initForManualUseWithOptions:dependencies:)
    public init(forManualUseWith options: Options, dependencies: SentryDependencyContainer) {
        self.integration = SentrySessionReplayIntegration<SentryDependencyContainer>(forManualUseWith: options, dependencies: dependencies)
        self.integration.startWithOptions(options.sessionReplay,
                                          experimentalOptions: options.experimental,
                                          fullSession: true)
    }
    
    // MARK: - SwiftIntegration protocol
    static var name: String {
        SentrySessionReplayIntegration<SentryDependencyContainer>.name
    }
    
    public func uninstall() {
        integration.uninstall()
    }
    
    // MARK: - Helpers to access API for SentrySessionReplayIntegration
    @objc public var sessionReplay: SentrySessionReplay? {
        get {
            return integration.sessionReplay
        }
        set {
            integration.sessionReplay = newValue
        }
    }
    
    @objc public var viewPhotographer: SentryViewPhotographer {
        integration.viewPhotographer
    }
    
    @objc public func pause() {
        integration.pause()
    }

    @objc public func resume() {
        integration.resume()
    }
    
    @objc public func stop() {
        integration.stop()
    }
    
    @objc public func start() {
        integration.start()
    }
    
    @objc public func showMaskPreview(_ opacity: Float) {
        integration.showMaskPreview(opacity)
    }
    
    @objc public func hideMaskPreview() {
        integration.hideMaskPreview()
    }
    
    @objc public func setReplayTags(_ tags: [String: Any]) {
        integration.setReplayTags(tags)
    }
    
    @objc @discardableResult public func captureReplay() -> Bool {
        integration.captureReplay()
    }
    
    @objc public func configureReplayWith(_ breadcrumbConverter: SentryReplayBreadcrumbConverter?, screenshotProvider: SentryViewScreenshotProvider?) {
        integration.configureReplayWith(breadcrumbConverter, screenshotProvider: screenshotProvider)
    }
    
    @objc public func sentrySessionStarted(session: SentrySession) {
        integration.sentrySessionStarted(session: session)
    }
    
    // MARK: - Test only functions
#if SENTRY_TEST || SENTRY_TEST_CI

    // Helper function to cast SentrySessionReplayIntegrationObjC to SentryIntegrationProtocol
    // Used only for testing with `addInstalledIntegration` or it fails to compile
    func addItselfToSentryHub(hub: SentryHubInternal) {
        hub.addInstalledIntegration(self, name: Self.name)
    }
    
    public func replayDirectory() -> URL? {
        integration.replayDirectory()
    }
    
    public func moveCurrentReplay() {
        integration.moveCurrentReplay()
    }
    
    public func sessionReplayNewSegment(
        replayEvent: SentryReplayEvent,
        replayRecording: SentryReplayRecording,
        videoUrl: URL
    ) {
        integration.sessionReplayNewSegment(replayEvent: replayEvent,
                                            replayRecording: replayRecording,
                                            videoUrl: videoUrl)
    }
    
    public func currentScreenNameForSessionReplay() -> String? {
        return integration.currentScreenNameForSessionReplay()
    }
    
    public func getTouchTracker() -> SentryTouchTracker? {
        return integration.getTouchTracker()
    }
    
    public func connectivityChanged(_ connected: Bool, typeDescription: String) {
        integration.connectivityChanged(connected, typeDescription: typeDescription)
    }
    
    public var replayProcessingQueue: SentryDispatchQueueWrapper {
        integration.replayProcessingQueue
    }
    
    public var replayAssetWorkerQueue: SentryDispatchQueueWrapper {
        integration.replayAssetWorkerQueue
    }
#endif
}

#endif
