@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

typealias SessionReplayIntegrationScope = SessionReplayEnvironmentCheckerProvider & NotificationCenterProvider & RateLimitsProvider & CurrentDateProvider & RandomProvider & FileManagerProvider & CrashWrapperProvider & ReachabilityProvider & GlobalEventProcessorProvider & DispatchQueueWrapperProvider & ApplicationProvider & DispatchFactoryProvider

// This is static because it will be used for swizzling and would cause retain cycles
private var touchTracker: SentryTouchTracker?

// swiftlint:disable type_body_length
// This class should be final but we are subclassing it in tests
@_spi(Private) @objc
public class SentrySessionReplayIntegration: NSObject, SwiftIntegration, SentrySessionReplayDelegate, SentrySessionListener, SentryReachabilityObserver {
    
    // MARK: - Properties
    var replayProcessingQueue: SentryDispatchQueueWrapper
    var replayAssetWorkerQueue: SentryDispatchQueueWrapper
    @objc public var sessionReplay: SentrySessionReplay?
    @objc public let viewPhotographer: SentryViewPhotographer
    
    private let replayOptions: SentryReplayOptions
    private let rateLimits: RateLimits
    private let random: SentryRandomProtocol
    private let application: SentryApplication?
    private var startedAsFullSession = false
    private let experimentalOptions: SentryExperimentalOptions
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private var currentScreenshotProvider: SentryViewScreenshotProvider?
    private var currentBreadcrumbConverter: SentryReplayBreadcrumbConverter?
    private var previewView: SentryMaskingPreviewView?
    private let dateProvider: SentryCurrentDateProvider
    private let crashWrapper: SentryCrashWrapper
    private let replayFileManager: SessionReplayFileManager
    private var replayRecovery: SessionReplayRecovery?
    
    /// We need to use this variable to identify whether rate limiting was ever activated for session replay
    /// in this session, instead of always looking for the rate status in `SentryRateLimits`. This is the
    /// easiest way to ensure segment 0 will always reach the server, because session replay needs segment 0.
    private var rateLimited = false
    @objc public static var name: String { "SentrySessionReplayIntegration" }

    // MARK: - Initialization

    required convenience init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard SentrySessionReplay.shouldEnableSessionReplay(
            environmentChecker: dependencies.sessionReplayEnvironmentChecker,
            experimentalOptions: options.experimental
        ) else {
            SentrySDKLog.debug("Not going to enable SentrySessionReplayIntegration because environment check failed.")
            return nil
        }

        guard options.sessionReplay.sessionSampleRate > 0 || options.sessionReplay.onErrorSampleRate > 0 else {
            SentrySDKLog.debug("Not going to enable SentrySessionReplayIntegration because sample rates are 0.")
            return nil
        }

        self.init(nonOptionalWith: options, dependencies: dependencies)
    }
    
    @objc
    public convenience init(forManualUseWith options: Options, dependencies: SentryDependencyContainer) {
        self.init(nonOptionalWith: options, dependencies: dependencies)
        startWithOptions(options.sessionReplay,
                         experimentalOptions: options.experimental,
                         fullSession: true)
    }
    
    init(nonOptionalWith options: Options, dependencies: SessionReplayIntegrationScope) {
        self.replayOptions = options.sessionReplay
        self.experimentalOptions = options.experimental
        self.notificationCenter = dependencies.notificationCenterWrapper
        self.rateLimits = dependencies.rateLimits
        self.dateProvider = dependencies.dateProvider
        self.random = dependencies.random
        self.crashWrapper = dependencies.crashWrapper
        self.application = dependencies.application()
        
        self.replayFileManager = SessionReplayFileManager(
            fileManager: dependencies.fileManager,
            sharedDispatchQueue: dependencies.dispatchQueueWrapper
        )
        
        self.viewPhotographer = Self.createViewPhotographer(options: options)
        (self.replayProcessingQueue, self.replayAssetWorkerQueue) = Self.createDispatchQueues(dependencies: dependencies)
        
        super.init()
        
        self.replayRecovery = SessionReplayRecovery(
            replayOptions: replayOptions,
            random: random,
            replayProcessingQueue: replayProcessingQueue,
            replayAssetWorkerQueue: replayAssetWorkerQueue,
            replayFileManager: replayFileManager
        )
        
        setupTouchTrackerIfNeeded(options: options)
        replayFileManager.moveCurrentReplay()
        replayFileManager.cleanUp()
        registerEventProcessor(dependencies: dependencies)
        
        SentrySDKInternal.currentHub().registerSessionListener(self)
        dependencies.reachability.add(self)
    }

    public func uninstall() {
        SentrySDKLog.debug("[Session Replay] Uninstalling")
        SentrySDKInternal.currentHub().unregisterSessionListener(self)
        touchTracker = nil
        pause()
    }

    deinit {
        SentrySDKLog.debug("[Session Replay] Deinit")
        uninstall()
    }
    
    // MARK: - Initialization Helpers
    
    private static func createViewPhotographer(options: Options) -> SentryViewPhotographer {
        var viewRenderer: SentryViewRenderer
        
        if options.sessionReplay.enableViewRendererV2 {
            SentrySDKLog.debug("[Session Replay] Setting up view renderer v2, fast view rendering: \(options.sessionReplay.enableFastViewRendering)")
            viewRenderer = SentryViewRendererV2(enableFastViewRendering: options.sessionReplay.enableFastViewRendering)
        } else {
            SentrySDKLog.debug("[Session Replay] Setting up default view renderer")
            viewRenderer = SentryDefaultViewRenderer()
        }
        // We are using the flag for the view renderer V2 also for the mask renderer V2, as it would
        // just introduce another option without affecting the SDK user experience.
        return SentryViewPhotographer(renderer: viewRenderer, redactOptions: options.sessionReplay, enableMaskRendererV2: options.sessionReplay.enableViewRendererV2)
    }
    
    private static func createDispatchQueues(dependencies: SessionReplayIntegrationScope) -> (processing: SentryDispatchQueueWrapper, assetWorker: SentryDispatchQueueWrapper) {
        // The asset worker queue handles video and frames data (priority -1).
        // The processing queue waits for asset worker to finish - must have lower priority (-2) to avoid deadlock.
        let assetWorkerQueue = dependencies.dispatchFactory.createUtilityQueue("io.sentry.session-replay.asset-worker", relativePriority: -1)
        let processingQueue = dependencies.dispatchFactory.createUtilityQueue("io.sentry.session-replay.processing", relativePriority: -2)
        return (processingQueue, assetWorkerQueue)
    }
    
    private func setupTouchTrackerIfNeeded(options: Options) {
        guard options.enableSwizzling else { return }
        SentrySDKLog.debug("[Session Replay] Setting up touch tracker, scale: \(replayOptions.sizeScale)")
        touchTracker = SentryTouchTracker(dateProvider: dateProvider, scale: options.sessionReplay.sizeScale)
        SentrySwizzleWrapperHelper.swizzleSendEvent { event in
            guard let event = event else { return }
            touchTracker?.trackTouchFrom(event: event)
        }
    }
    
    private func registerEventProcessor(dependencies: SessionReplayIntegrationScope) {
        dependencies.globalEventProcessor.add { [weak self] event in
            guard let self = self else { return event }
            if event.isFatalEvent {
                self.replayRecovery?.resumePreviousSessionReplay(event)
            } else {
                self.sessionReplay?.captureReplayFor(event: event)
            }
            return event
        }
    }

    // MARK: - Session Listener

    public func sentrySessionStarted(session: SentrySession) {
        SentrySDKLog.debug("[Session Replay] Session started")
        rateLimited = false
        startSession()
    }

    public func sentrySessionEnded(session: SentrySession) {
        SentrySDKLog.debug("[Session Replay] Session ended")
        pause()
        removeBackgroundForegroundObservers()
        sessionReplay = nil
    }

    private func startSession() {
        SentrySDKLog.debug("[Session Replay] Starting session")
        sessionReplay?.pause()
        startedAsFullSession = random.nextNumber() < Double(replayOptions.sessionSampleRate)
        
        if !startedAsFullSession && replayOptions.onErrorSampleRate == 0 {
            SentrySDKLog.debug("[Session Replay] Not full session and onErrorSampleRate is 0, not starting session")
            return
        }
        
        runReplayForAvailableWindow()
    }

    private func runReplayForAvailableWindow() {
        if application?.getWindows()?.count ?? 0 > 0 {
            SentrySDKLog.debug("[Session Replay] Running replay for available window")
            // If a window its already available start replay right away
            startWithOptions(replayOptions, experimentalOptions: experimentalOptions, fullSession: startedAsFullSession)
        } else {
            SentrySDKLog.debug("[Session Replay] Waiting for a scene to be available to started the replay")
            // Wait for a scene to be available to started the replay
            notificationCenter.addObserver(self, selector: #selector(newSceneActivate), name: UIScene.didActivateNotification, object: nil)
        }
    }

    @objc private func newSceneActivate() {
        SentrySDKLog.debug("[Session Replay] Scene is available, starting replay")
        notificationCenter.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
        startWithOptions(replayOptions, experimentalOptions: experimentalOptions, fullSession: startedAsFullSession)
    }

    // MARK: - Session Replay Setup

    func startWithOptions(_ replayOptions: SentryReplayOptions, experimentalOptions: SentryExperimentalOptions, fullSession: Bool) {
        startWithOptions(replayOptions, experimentalOptions: experimentalOptions,
                        screenshotProvider: currentScreenshotProvider ?? viewPhotographer,
                        breadcrumbConverter: currentBreadcrumbConverter ?? SentrySRDefaultBreadcrumbConverter(),
                        fullSession: fullSession)
    }

    private func startWithOptions(_ replayOptions: SentryReplayOptions, experimentalOptions: SentryExperimentalOptions,
                                  screenshotProvider: SentryViewScreenshotProvider, breadcrumbConverter: SentryReplayBreadcrumbConverter, fullSession: Bool) {
        SentrySDKLog.debug("[Session Replay] Starting session")
        guard let sessionDocs = replayFileManager.createSessionDirectory() else {
            SentrySDKLog.warning("[Session Replay] Failed to create session direcotry, cancelling starting session")
            return
        }
        
        let replayMaker = createReplayMaker(outputPath: sessionDocs.path, fullSession: fullSession)
        let newSessionReplay = SentrySessionReplay(
            replayOptions: replayOptions, replayFolderPath: sessionDocs, screenshotProvider: screenshotProvider,
            replayMaker: replayMaker, breadcrumbConverter: breadcrumbConverter, touchTracker: touchTracker,
            dateProvider: dateProvider, delegate: self, displayLinkWrapper: SentryDisplayLinkWrapper())

        self.sessionReplay = newSessionReplay
        newSessionReplay.start(rootView: application?.getWindows()?.first, fullSession: fullSession)
        addBackgroundForegroundObservers()
        
        if let replayId = newSessionReplay.sessionReplayId {
            replayFileManager.saveCurrentSessionInfo(replayId, path: sessionDocs.path, options: replayOptions)
        }
    }
    
    private func createReplayMaker(outputPath: String, fullSession: Bool) -> SentryOnDemandReplay {
        let replayMaker = SentryOnDemandReplay(outputPath: outputPath, processingQueue: replayProcessingQueue, assetWorkerQueue: replayAssetWorkerQueue)
        replayMaker.bitRate = replayOptions.replayBitRate
        replayMaker.videoScale = replayOptions.sizeScale
        replayMaker.frameRate = Int(replayOptions.frameRate)
        // The cache should be at least the amount of frames fitting into the session segment duration
        // plus one frame to ensure that the last frame is not dropped.
        let duration = Int(fullSession ? replayOptions.sessionSegmentDuration : replayOptions.errorReplayDuration)
        replayMaker.cacheMaxSize = UInt((duration * Int(replayOptions.frameRate)) + 1)
        return replayMaker
    }

    // MARK: - Notification Observers
    
    private func addBackgroundForegroundObservers() {
        notificationCenter.addObserver(self, selector: #selector(pause), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func removeBackgroundForegroundObservers() {
        notificationCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    // MARK: - API Exposed to ObjC
    
    @objc public func pause() {
        SentrySDKLog.debug("[Session Replay] Pausing session")
        sessionReplay?.pause()
    }
    
    @objc public func resume() {
        SentrySDKLog.debug("[Session Replay] Resuming session")
        sessionReplay?.resume()
    }

    @objc public func start() {
        SentrySDKLog.debug("[Session Replay] Starting session")
        if rateLimited {
            SentrySDKLog.warning("[Session Replay] This session was rate limited. Not starting session replay until next app session")
            return
        }
        if let replay = sessionReplay {
            if !replay.isFullSession {
                replay.captureReplay()
            }
            return
        }
        startedAsFullSession = true
        runReplayForAvailableWindow()
    }

    @objc public func stop() {
        SentrySDKLog.debug("[Session Replay] Stopping session")
        sessionReplay?.pause()
        sessionReplay = nil 
    }

    @objc @discardableResult public func captureReplay() -> Bool {
        SentrySDKLog.debug("[Session Replay] Capturing replay")
        return sessionReplay?.captureReplay() ?? false 
    }

    @objc public func configureReplayWith(_ breadcrumbConverter: SentryReplayBreadcrumbConverter?, screenshotProvider: SentryViewScreenshotProvider?) {
        SentrySDKLog.debug("[Session Replay] Configuring replay")
        if let bc = breadcrumbConverter {
            currentBreadcrumbConverter = bc
            sessionReplay?.breadcrumbConverter = bc
        }
        if let sp = screenshotProvider {
            currentScreenshotProvider = sp
            sessionReplay?.screenshotProvider = sp
        }
    }

    @objc public func setReplayTags(_ tags: [String: Any]) {
        SentrySDKLog.debug("[Session Replay] Setting replay tags: \(tags)")
        sessionReplay?.replayTags = tags 
    }

    @objc public func showMaskPreview(_ opacity: Float) {
        SentrySDKLog.debug("[Session Replay] Showing mask preview with opacity: \(opacity)")
        guard crashWrapper.isBeingTraced else { 
            SentrySDKLog.debug("[Session Replay] No tracing is active, not showing mask preview")
            return 
        }
        guard let window = application?.getWindows()?.first else { 
            SentrySDKLog.debug("[Session Replay] No UIWindow available to display preview")
            return 
        }
        if previewView == nil { previewView = SentryMaskingPreviewView(redactOptions: replayOptions) }
        previewView?.opacity = opacity
        previewView?.frame = window.bounds
        if let pv = previewView { window.addSubview(pv) }
    }

    @objc public func hideMaskPreview() { 
        SentrySDKLog.debug("[Session Replay] Hiding mask preview")
        previewView?.removeFromSuperview()
        previewView = nil 
    }

    // MARK: - SentrySessionReplayDelegate
    public func sessionReplayShouldCaptureReplayForError() -> Bool { random.nextNumber() <= Double(replayOptions.onErrorSampleRate) }

    public func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL) {
        SentrySDKLog.debug("[Session Replay] New segment with replay event, eventId: \(replayEvent.eventId), segmentId: \(replayEvent.segmentId)")

        if rateLimits.isRateLimitActive(SentryDataCategory.replay.rawValue) || rateLimits.isRateLimitActive(SentryDataCategory.all.rawValue) {
            rateLimited = true
            stop()
            return
        }
        guard let timestamp = replayEvent.timestamp else { return }
        SentrySDKInternal.currentHub().captureReplayEvent(replayEvent, replayRecording: replayRecording, video: videoUrl)
        sentrySessionReplaySync_updateInfo(UInt32(replayEvent.segmentId), timestamp.timeIntervalSinceReferenceDate)
    }

    public func sessionReplayStarted(replayId: SentryId) {
        SentrySDKLog.debug("[Session Replay] Session replay started with replayId: \(replayId.sentryIdString)")
        SentrySDKInternal.currentHub().configureScope { scope in scope.replayId = replayId.sentryIdString }
    }

    public func breadcrumbsForSessionReplay() -> [Breadcrumb] {
        var result: [Breadcrumb] = []
        SentrySDKInternal.currentHub().configureScope { scope in result = scope.breadcrumbs() }
        return result
    }

    public func currentScreenNameForSessionReplay() -> String? {
        SentrySDKInternal.currentHub().scope.currentScreen ?? application?.relevantViewControllersNames()?.first ?? ""
    }

    // MARK: - SentryReachabilityObserver
    public func connectivityChanged(_ connected: Bool, typeDescription: String) {
        SentrySDKLog.debug("[Session Replay] Connectivity changed to: \(connected ? "connected" : "disconnected"), type: \(typeDescription)")
        if connected { sessionReplay?.resume() } else { sessionReplay?.pauseSessionMode() }
    }
    
    // MARK: - Test only
#if SENTRY_TEST || SENTRY_TEST_CI
    func replayDirectory() -> URL? { replayFileManager.replayDirectory() }
    
    func moveCurrentReplay() { replayFileManager.moveCurrentReplay() }
    
    func getTouchTracker() -> SentryTouchTracker? { touchTracker }
    
    // Helper function to cast SentrySessionReplayIntegration to SentryIntegrationProtocol
    // Used only for testing with `addInstalledIntegration` or it fails to compile
    func addItselfToSentryHub(hub: SentryHubInternal) {
        hub.addInstalledIntegration(self, name: Self.name)
    }
#endif
}
// swiftlint:enable type_body_length

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
