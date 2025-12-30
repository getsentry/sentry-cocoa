@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

typealias SessionReplayIntegrationScope = SessionReplayEnvironmentCheckerProvider & NotificationCenterProvider & RateLimitsProvider & CurrentDateProvider & RandomProvider & FileManagerProvider & CrashWrapperProvider & ReachabilityProvider & GlobalEventProcessorProvider & DispatchQueueWrapperProvider & ApplicationProvider & DispatchFactoryProvider

// This is static because it will be used for swizzling and would cause retain cycles
private var touchTracker: SentryTouchTracker?

final class SentrySessionReplayIntegration<Dependencies: SessionReplayIntegrationScope>: NSObject, SwiftIntegration, SentrySessionReplayDelegate, SentrySessionListener, SentryReachabilityObserver {
    
    // MARK: - Properties
    var replayProcessingQueue: SentryDispatchQueueWrapper
    var replayAssetWorkerQueue: SentryDispatchQueueWrapper
    var sessionReplay: SentrySessionReplay?
    let viewPhotographer: SentryViewPhotographer
    
    private let replayOptions: SentryReplayOptions
    private let rateLimits: RateLimits
    private var rateLimited = false
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
    
    static var name: String { "SentrySessionReplayIntegration" }

    // MARK: - Initialization

    convenience init?(with options: Options, dependencies: SessionReplayIntegrationScope) {
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
    
    convenience init(forManualUseWith options: Options, dependencies: SessionReplayIntegrationScope) {
        self.init(nonOptionalWith: options, dependencies: dependencies)
    }
    
    private init(nonOptionalWith options: Options, dependencies: SessionReplayIntegrationScope) {
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

    func uninstall() {
        SentrySDKLog.debug("[Session Replay] Uninstalling")
        SentrySDKInternal.currentHub().unregisterSessionListener(self)
        touchTracker = nil
        pause()
    }
    
    // MARK: - Initialization Helpers
    
    private static func createViewPhotographer(options: Options) -> SentryViewPhotographer {
        let viewRenderer: SentryViewRenderer = options.sessionReplay.enableViewRendererV2
            ? SentryViewRendererV2(enableFastViewRendering: options.sessionReplay.enableFastViewRendering)
            : SentryDefaultViewRenderer()
        return SentryViewPhotographer(renderer: viewRenderer, redactOptions: options.sessionReplay, enableMaskRendererV2: options.sessionReplay.enableViewRendererV2)
    }
    
    private static func createDispatchQueues(dependencies: SessionReplayIntegrationScope) -> (processing: SentryDispatchQueueWrapper, assetWorker: SentryDispatchQueueWrapper) {
        (dependencies.dispatchFactory.createUtilityQueue("io.sentry.session-replay.processing", relativePriority: -2),
         dependencies.dispatchFactory.createUtilityQueue("io.sentry.session-replay.asset-worker", relativePriority: -1))
    }
    
    private func setupTouchTrackerIfNeeded(options: Options) {
        guard options.enableSwizzling else { return }
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

    func sentrySessionStarted(session: SentrySession) {
        rateLimited = false
        startSession()
    }

    func sentrySessionEnded(session: SentrySession) {
        pause()
        removeBackgroundForegroundObservers()
        sessionReplay = nil
    }

    private func startSession() {
        sessionReplay?.pause()
        startedAsFullSession = random.nextNumber() < Double(replayOptions.sessionSampleRate)
        if !startedAsFullSession && replayOptions.onErrorSampleRate == 0 { return }
        runReplayForAvailableWindow()
    }

    private func runReplayForAvailableWindow() {
        if application?.getWindows()?.count ?? 0 > 0 {
            startWithOptions(replayOptions, experimentalOptions: experimentalOptions, fullSession: startedAsFullSession)
        } else {
            notificationCenter.addObserver(self, selector: #selector(newSceneActivate), name: UIScene.didActivateNotification, object: nil)
        }
    }

    @objc private func newSceneActivate() {
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
        guard let sessionDocs = replayFileManager.createSessionDirectory() else { return }
        
        let replayMaker = createReplayMaker(outputPath: sessionDocs.path, fullSession: fullSession)
        let newSessionReplay = SentrySessionReplay(
            replayOptions: replayOptions, replayFolderPath: sessionDocs, screenshotProvider: screenshotProvider,
            replayMaker: replayMaker, breadcrumbConverter: breadcrumbConverter, touchTracker: touchTracker,
            dateProvider: dateProvider, delegate: self, displayLinkWrapper: SentryDisplayLinkWrapper())

        self.sessionReplay = newSessionReplay
        newSessionReplay.start(rootView: application?.getWindows()?.first, fullSession: fullSession)
        addBackgroundForegroundObservers()

        guard let replayId = newSessionReplay.sessionReplayId else { return }
        replayFileManager.saveCurrentSessionInfo(replayId, path: sessionDocs.path, options: replayOptions)
    }
    
    private func createReplayMaker(outputPath: String, fullSession: Bool) -> SentryOnDemandReplay {
        let replayMaker = SentryOnDemandReplay(outputPath: outputPath, processingQueue: replayProcessingQueue, assetWorkerQueue: replayAssetWorkerQueue)
        replayMaker.bitRate = replayOptions.replayBitRate
        replayMaker.videoScale = replayOptions.sizeScale
        replayMaker.frameRate = Int(replayOptions.frameRate)
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
    
    // MARK: - Public API for Testing
    func replayDirectory() -> URL? { replayFileManager.replayDirectory() }
    func moveCurrentReplay() { replayFileManager.moveCurrentReplay() }

    // MARK: - Pause/Resume
    @objc func pause() { sessionReplay?.pause() }
    @objc func resume() { sessionReplay?.resume() }

    // MARK: - Public API

    func start() {
        if rateLimited { return }
        if let replay = sessionReplay, !replay.isFullSession { _ = replay.captureReplay(); return }
        startedAsFullSession = true
        runReplayForAvailableWindow()
    }

    func stop() { sessionReplay?.pause(); sessionReplay = nil }

    @discardableResult func captureReplay() -> Bool { sessionReplay?.captureReplay() ?? false }

    func configureReplayWith(_ breadcrumbConverter: SentryReplayBreadcrumbConverter?, screenshotProvider: SentryViewScreenshotProvider?) {
        if let bc = breadcrumbConverter { currentBreadcrumbConverter = bc; sessionReplay?.breadcrumbConverter = bc }
        if let sp = screenshotProvider { currentScreenshotProvider = sp; sessionReplay?.screenshotProvider = sp }
    }

    func setReplayTags(_ tags: [String: Any]) { sessionReplay?.replayTags = tags }

    func showMaskPreview(_ opacity: Float) {
        guard crashWrapper.isBeingTraced, let window = application?.getWindows()?.first else { return }
        if previewView == nil { previewView = SentryMaskingPreviewView(redactOptions: replayOptions) }
        previewView?.opacity = opacity
        previewView?.frame = window.bounds
        if let pv = previewView { window.addSubview(pv) }
    }

    func hideMaskPreview() { previewView?.removeFromSuperview(); previewView = nil }

    // MARK: - SentrySessionReplayDelegate
    func sessionReplayShouldCaptureReplayForError() -> Bool { random.nextNumber() <= Double(replayOptions.onErrorSampleRate) }

    func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL) {
        if rateLimits.isRateLimitActive(SentryDataCategory.replay.rawValue) || rateLimits.isRateLimitActive(SentryDataCategory.all.rawValue) {
            rateLimited = true; stop(); return
        }
        guard let timestamp = replayEvent.timestamp else { return }
        SentrySDKInternal.currentHub().captureReplayEvent(replayEvent, replayRecording: replayRecording, video: videoUrl)
        sentrySessionReplaySync_updateInfo(UInt32(replayEvent.segmentId), timestamp.timeIntervalSinceReferenceDate)
    }

    func sessionReplayStarted(replayId: SentryId) {
        SentrySDKInternal.currentHub().configureScope { scope in scope.replayId = replayId.sentryIdString }
    }

    func breadcrumbsForSessionReplay() -> [Breadcrumb] {
        var result: [Breadcrumb] = []
        SentrySDKInternal.currentHub().configureScope { scope in result = scope.breadcrumbs() }
        return result
    }

    func currentScreenNameForSessionReplay() -> String? {
        SentrySDKInternal.currentHub().scope.currentScreen ?? application?.relevantViewControllersNames()?.first ?? ""
    }

    // MARK: - SentryReachabilityObserver
    func connectivityChanged(_ connected: Bool, typeDescription: String) {
        if connected { sessionReplay?.resume() } else { sessionReplay?.pauseSessionMode() }
    }
    
    // MARK: Test only
#if SENTRY_TEST || SENTRY_TEST_CI
    func getTouchTracker() -> SentryTouchTracker? { touchTracker }
#endif
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
