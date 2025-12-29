//swiftlint:disable file_length
@_implementationOnly import _SentryPrivate

@objc
@_spi(Private) public protocol SentrySessionListener {
    @objc func sentrySessionEnded(session: SentrySession)
    @objc func sentrySessionStarted(session: SentrySession)
}

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

typealias SessionReplayIntegrationScope = SessionReplayEnvironmentCheckerProvider & NotificationCenterProvider & RateLimitsProvider & CurrentDateProvider & RandomProvider & FileManagerProvider & CrashWrapperProvider & ReachabilityProvider & GlobalEventProcessorProvider & DispatchQueueWrapperProvider & ApplicationProvider & DispatchFactoryProvider

private typealias CrossPlatformApplication = UIApplication

// This is static because it will be used for swizzling and would cause retain cycles
fileprivate var touchTracker: SentryTouchTracker?

#if SENTRY_TEST || SENTRY_TEST_CI
// This non final class is used for testing
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
        self.integration = SentrySessionReplayIntegration<SentryDependencyContainer>(nonOptionalWith: options, dependencies: dependencies)
        self.integration.startWithOptions(options.sessionReplay,
                                          experimentalOptions: options.experimental,
                                          fullSession: true)
    }
}
#else
@_spi(Private) @objc
public final class SentrySessionReplayIntegrationObjC: NSObject, SwiftIntegration {
    
    private let integration: SentrySessionReplayIntegration<SentryDependencyContainer>
    
    @objc
    public init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard let integration = SentrySessionReplayIntegration<SentryDependencyContainer>(with: options, dependencies: dependencies) else {
            return nil
        }
        self.integration = integration
    }
    
    @objc(initForManualUseWithOptions:dependencies:)
    public init(forManualUseWith options: Options, dependencies: SentryDependencyContainer) {
        self.integration = SentrySessionReplayIntegration<SentryDependencyContainer>(nonOptionalWith: options, dependencies: dependencies)
        self.integration.startWithOptions(options.sessionReplay,
                                          experimentalOptions: options.experimental,
                                          fullSession: true)
    }
}
#endif

extension SentrySessionReplayIntegrationObjC {
    
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

    static var name: String {
        SentrySessionReplayIntegration<SentryDependencyContainer>.name
    }
    
    public func uninstall() {
        integration.uninstall()
    }
    
    @objc
    public static func shouldEnable(for options: Options, environmentChecker: SentrySessionReplayEnvironmentCheckerProvider) -> Bool {
        return SentrySessionReplay.shouldEnableSessionReplay(
            environmentChecker: environmentChecker,
            experimentalOptions: options.experimental
        )
    }
    
    @objc
    public func pause() {
        integration.pause()
    }

    @objc
    public func resume() {
        integration.resume()
    }
    
    @objc
    public func stop() {
        integration.stop()
    }
    
    @objc
    public func start() {
        integration.start()
    }
    
    @objc
    public func showMaskPreview(_ opacity: Float) {
        integration.showMaskPreview(opacity)
    }
    
    @objc
    public func hideMaskPreview() {
        integration.hideMaskPreview()
    }
    
    @objc
    public func setReplayTags(_ tags: [String: Any]) {
        integration.setReplayTags(tags)
    }
    
    @objc
    @discardableResult
    public func captureReplay() -> Bool {
        integration.captureReplay()
    }
    
    @objc
    public func configureReplayWith(_ breadcrumbConverter: SentryReplayBreadcrumbConverter?, screenshotProvider: SentryViewScreenshotProvider?) {
        integration.configureReplayWith(breadcrumbConverter, screenshotProvider: screenshotProvider)
    }
    
    @objc
    public func sentrySessionStarted(session: SentrySession) {
        integration.sentrySessionStarted(session: session)
    }
    
#if SENTRY_TEST || SENTRY_TEST_CI
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
        return touchTracker
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

//swiftlint:disable type_body_length
final class SentrySessionReplayIntegration<Dependencies: SessionReplayIntegrationScope>: NSObject, SwiftIntegration, SentrySessionReplayDelegate, SentrySessionListener, SentryReachabilityObserver {
    private var startedAsFullSession = false
    private let replayOptions: SentryReplayOptions
    private let experimentalOptions: SentryExperimentalOptions
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private let rateLimits: RateLimits
    private var currentScreenshotProvider: SentryViewScreenshotProvider?
    private var currentBreadcrumbConverter: SentryReplayBreadcrumbConverter?
    private var previewView: SentryMaskingPreviewView?
    private var rateLimited = false
    private let dateProvider: SentryCurrentDateProvider
    private let random: SentryRandomProtocol
    private let fileManager: SentryFileManager?
    private let globalEventProcessor: SentryGlobalEventProcessor
    private let reachability: SentryReachability
    private let crashWrapper: SentryCrashWrapper
    private let application: SentryApplication?
    private let sharedDispatchQueue: SentryDispatchQueueWrapper
    private let dispatchFactory: SentryDispatchFactory

    fileprivate var replayProcessingQueue: SentryDispatchQueueWrapper
    fileprivate var replayAssetWorkerQueue: SentryDispatchQueueWrapper

    @objc public var sessionReplay: SentrySessionReplay?
    @objc public let viewPhotographer: SentryViewPhotographer
    
    static var name: String {
        "SentrySessionReplayIntegration"
    }

    convenience public init?(with options: Options, dependencies: SessionReplayIntegrationScope) {
        // Check if session replay should be enabled
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
    
    convenience public init(forManualUseWith options: Options, dependencies: SentryDependencyContainer) {
        self.init(nonOptionalWith: options, dependencies: dependencies)
    }
    
    //swiftlint:disable function_body_length
    fileprivate init(nonOptionalWith options: Options, dependencies: SessionReplayIntegrationScope) {
        self.replayOptions = options.sessionReplay
        self.experimentalOptions = options.experimental
        self.notificationCenter = dependencies.notificationCenterWrapper
        self.rateLimits = dependencies.rateLimits
        self.dateProvider = dependencies.dateProvider
        self.random = dependencies.random
        self.fileManager = dependencies.fileManager
        self.globalEventProcessor = dependencies.globalEventProcessor
        self.reachability = dependencies.reachability
        self.crashWrapper = dependencies.crashWrapper
        self.application = dependencies.application()
        self.sharedDispatchQueue = dependencies.dispatchQueueWrapper
        self.dispatchFactory = dependencies.dispatchFactory

        // Setup view renderer
        let viewRenderer: SentryViewRenderer
        if options.sessionReplay.enableViewRendererV2 {
            SentrySDKLog.debug("[Session Replay] Setting up view renderer v2, fast view rendering: \(options.sessionReplay.enableFastViewRendering)")
            viewRenderer = SentryViewRendererV2(enableFastViewRendering: options.sessionReplay.enableFastViewRendering)
        } else {
            SentrySDKLog.debug("[Session Replay] Setting up default view renderer")
            viewRenderer = SentryDefaultViewRenderer()
        }

        self.viewPhotographer = SentryViewPhotographer(
            renderer: viewRenderer,
            redactOptions: options.sessionReplay,
            enableMaskRendererV2: options.sessionReplay.enableViewRendererV2
        )

        // Setup dispatch queues
        replayAssetWorkerQueue = dispatchFactory.createUtilityQueue(
            "io.sentry.session-replay.asset-worker",
            relativePriority: -1
        )

        replayProcessingQueue = dispatchFactory.createUtilityQueue(
            "io.sentry.session-replay.processing",
            relativePriority: -2
        )
        
        super.init()
        
        // Setup touch tracker if swizzling is enabled
        if options.enableSwizzling {
            SentrySDKLog.debug("[Session Replay] Setting up touch tracker, scale: \(options.sessionReplay.sizeScale)")
            touchTracker = SentryTouchTracker(
                dateProvider: dateProvider,
                scale: options.sessionReplay.sizeScale
            )
            swizzleApplicationTouch()
        }

        moveCurrentReplay()
        cleanUp()

        SentrySDKInternal.currentHub().registerSessionListener(self)

        // Add event processor
        globalEventProcessor.add { [weak self] event in
            guard let self = self else {
                SentrySDKLog.debug("WeakSelf is nil. Not doing anything.")
                return event
            }

            if event.isFatalEvent {
                self.resumePreviousSessionReplay(event)
            } else {
                self.sessionReplay?.captureReplayFor(event: event)
            }
            return event
        }

        reachability.add(self)
    }
    //swiftlint:enable function_body_length

    @objc public func install(with options: Options) -> Bool {
        // This is called by old ObjC installation code, but for SwiftIntegration
        // the actual initialization happens in init?(with:dependencies:)
        return true
    }

    @objc public func uninstall() {
        SentrySDKLog.debug("[Session Replay] Uninstalling")
        SentrySDKInternal.currentHub().unregisterSessionListener(self)
        touchTracker = nil
        pause()
    }

    @objc public static var integrationName: String {
        "SentrySessionReplayIntegration"
    }

    // MARK: - Session Listener

    @objc public func sentrySessionStarted(session: SentrySession) {
        SentrySDKLog.debug("[Session Replay] Session started")
        rateLimited = false
        startSession()
    }

    @objc public func sentrySessionEnded(session: SentrySession) {
        SentrySDKLog.debug("[Session Replay] Session ended")
        pause()
        notificationCenter.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        notificationCenter.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        sessionReplay = nil
    }

    private func startSession() {
        SentrySDKLog.debug("[Session Replay] Starting session")
        sessionReplay?.pause()

        startedAsFullSession = shouldReplayFullSession(Double(replayOptions.sessionSampleRate))

        if !startedAsFullSession && replayOptions.onErrorSampleRate == 0 {
            SentrySDKLog.debug("[Session Replay] Not full session and onErrorSampleRate is 0, not starting session")
            return
        }

        runReplayForAvailableWindow()
    }

    private func runReplayForAvailableWindow() {
        if application?.getWindows()?.count ?? 0 > 0 {
            SentrySDKLog.debug("[Session Replay] Running replay for available window")
            startWithOptions(replayOptions, experimentalOptions: experimentalOptions, fullSession: startedAsFullSession)
        } else {
            SentrySDKLog.debug("[Session Replay] Waiting for a scene to be available to started the replay")
            notificationCenter.addObserver(
                self,
                selector: #selector(newSceneActivate),
                name: UIScene.didActivateNotification,
                object: nil
            )
        }
    }

    @objc private func newSceneActivate() {
        SentrySDKLog.debug("[Session Replay] Scene is available, starting replay")
        notificationCenter.removeObserver(
            self,
            name: UIScene.didActivateNotification,
            object: nil
        )
        startWithOptions(replayOptions, experimentalOptions: experimentalOptions, fullSession: startedAsFullSession)
    }

    fileprivate func startWithOptions(
        _ replayOptions: SentryReplayOptions,
        experimentalOptions: SentryExperimentalOptions,
        fullSession: Bool
    ) {
        startWithOptions(
            replayOptions,
            experimentalOptions: experimentalOptions,
            screenshotProvider: currentScreenshotProvider ?? viewPhotographer,
            breadcrumbConverter: currentBreadcrumbConverter ?? SentrySRDefaultBreadcrumbConverter(),
            fullSession: fullSession
        )
    }

    //swiftlint:disable function_body_length
    private func startWithOptions(
        _ replayOptions: SentryReplayOptions,
        experimentalOptions: SentryExperimentalOptions,
        screenshotProvider: SentryViewScreenshotProvider,
        breadcrumbConverter: SentryReplayBreadcrumbConverter,
        fullSession: Bool
    ) {
        SentrySDKLog.debug("[Session Replay] Starting session")
        guard let docs = replayDirectory() else {
            SentrySDKLog.error("[Session Replay] Could not get replay directory")
            return
        }

        let currentSession = UUID().uuidString
        let sessionDocs = docs.appendingPathComponent(currentSession)

        if !FileManager.default.fileExists(atPath: sessionDocs.path) {
            SentrySDKLog.debug("[Session Replay] Creating directory at path: \(sessionDocs.path)")
            try? FileManager.default.createDirectory(
                at: sessionDocs,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let replayMaker = SentryOnDemandReplay(
            outputPath: sessionDocs.path,
            processingQueue: replayProcessingQueue,
            assetWorkerQueue: replayAssetWorkerQueue
        )
        replayMaker.bitRate = replayOptions.replayBitRate
        replayMaker.videoScale = replayOptions.sizeScale
        replayMaker.frameRate = Int(replayOptions.frameRate)

        let sessionSegmentDuration = Int(fullSession ? replayOptions.sessionSegmentDuration : replayOptions.errorReplayDuration)
        replayMaker.cacheMaxSize = UInt((sessionSegmentDuration * Int(replayOptions.frameRate)) + 1)

        let displayLinkWrapper = SentryDisplayLinkWrapper()
        let newSessionReplay = SentrySessionReplay(
            replayOptions: replayOptions,
            replayFolderPath: sessionDocs,
            screenshotProvider: screenshotProvider,
            replayMaker: replayMaker,
            breadcrumbConverter: breadcrumbConverter,
            touchTracker: touchTracker,
            dateProvider: dateProvider,
            delegate: self,
            displayLinkWrapper: displayLinkWrapper
        )

        self.sessionReplay = newSessionReplay

        newSessionReplay.start(rootView: application?.getWindows()?.first, fullSession: fullSession)

        notificationCenter.addObserver(
            self,
            selector: #selector(pause),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(resume),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        guard let replayId = newSessionReplay.sessionReplayId else {
            SentrySDKLog.error("Failed to save current session info, replay id is nil")
            return
        }

        saveCurrentSessionInfo(replayId, path: sessionDocs.path, options: replayOptions)
    }
    //swiftlint:enable function_body_length

    // MARK: - File Management

    fileprivate func replayDirectory() -> URL? {
        guard let sentryPath = fileManager?.sentryPath else {
            return nil
        }
        let dir = URL(fileURLWithPath: sentryPath)
        return dir.appendingPathComponent("replay")
    }

    private func saveCurrentSessionInfo(_ sessionId: SentryId, path: String, options: SentryReplayOptions) {
        SentrySDKLog.debug("[Session Replay] Saving current session info for session: \(sessionId) to path: \(path)")
        var info: [String: Any] = [:]
        info["replayId"] = sessionId.sentryIdString
        info["path"] = (path as NSString).lastPathComponent
        info["errorSampleRate"] = options.onErrorSampleRate

        guard let data = SentrySerializationSwift.data(withJSONObject: info) else {
            SentrySDKLog.error("[Session Replay] Failed to serialize session info")
            return
        }

        let infoPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent("replay.current")
        if FileManager.default.fileExists(atPath: infoPath) {
            SentrySDKLog.debug("[Session Replay] Removing existing current replay info at path: \(infoPath)")
            try? FileManager.default.removeItem(atPath: infoPath)
        }
        try? data.write(to: URL(fileURLWithPath: infoPath), options: .atomic)

        SentrySDKLog.debug("[Session Replay] Saved current session info at path: \(infoPath)")
        let crashInfoPath = (path as NSString).appendingPathComponent("crashInfo")
        sentrySessionReplaySync_start(crashInfoPath)
    }

    fileprivate func moveCurrentReplay() {
        SentrySDKLog.debug("[Session Replay] Moving current replay")
        guard let path = replayDirectory() else { return }

        let current = path.appendingPathComponent("replay.current")
        let last = path.appendingPathComponent("replay.last")

        if FileManager.default.fileExists(atPath: last.path) {
            SentrySDKLog.debug("[Session Replay] Removing last replay file at path: \(last)")
            try? FileManager.default.removeItem(at: last)
            SentrySDKLog.debug("[Session Replay] Removed last replay file at path: \(last)")
        } else {
            SentrySDKLog.debug("[Session Replay] No last replay file to remove at path: \(last)")
        }

        if FileManager.default.fileExists(atPath: current.path) {
            SentrySDKLog.debug("[Session Replay] Moving current replay file at path: \(current) to: \(last)")
            try? FileManager.default.moveItem(at: current, to: last)
            SentrySDKLog.debug("[Session Replay] Moved current replay file at path: \(current)")
        } else {
            SentrySDKLog.debug("[Session Replay] No current replay file to move at path: \(current)")
        }
    }

    private func cleanUp() {
        SentrySDKLog.debug("[Session Replay] Cleaning up")
        guard let replayDir = replayDirectory(), let fileManager = fileManager else { return }

        let lastReplayInfo = lastReplayInfo()
        let lastReplayFolder = lastReplayInfo?["path"] as? String

        let replayFiles = fileManager.allFilesInFolder(replayDir.path)

        if replayFiles.count == 0 {
            SentrySDKLog.debug("[Session Replay] No replay files to clean up")
            return
        }

        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper.dispatchAsync {
            for file in replayFiles {
                if file == lastReplayFolder {
                    SentrySDKLog.debug("[Session Replay] Skipping last replay folder: \(file)")
                    continue
                }

                let filePath = (replayDir.path as NSString).appendingPathComponent(file)

                if fileManager.isDirectory(filePath) {
                    SentrySDKLog.debug("[Session Replay] Removing replay directory at path: \(filePath)")
                    fileManager.removeFile(atPath: filePath)
                }
            }
        }
    }

    // MARK: - Pause/Resume

    @objc
    fileprivate func pause() {
        SentrySDKLog.debug("[Session Replay] Pausing session")
        sessionReplay?.pause()
    }

    @objc
    fileprivate func resume() {
        SentrySDKLog.debug("[Session Replay] Resuming session")
        sessionReplay?.resume()
    }

    // MARK: - Public API

    @objc
    fileprivate func start() {
        SentrySDKLog.debug("[Session Replay] Starting session")
        if rateLimited {
            SentrySDKLog.warning("[Session Replay] This session was rate limited. Not starting session replay until next app session")
            return
        }

        if let replay = sessionReplay {
            if !replay.isFullSession {
                SentrySDKLog.debug("[Session Replay] Not full session, capturing replay")
                _ = replay.captureReplay()
            }
            return
        }

        startedAsFullSession = true
        runReplayForAvailableWindow()
    }

    @objc
    fileprivate func stop() {
        SentrySDKLog.debug("[Session Replay] Stopping session")
        sessionReplay?.pause()
        sessionReplay = nil
    }

    @objc
    @discardableResult
    fileprivate func captureReplay() -> Bool {
        SentrySDKLog.debug("[Session Replay] Capturing replay")
        return sessionReplay?.captureReplay() ?? false
    }

    @objc
    fileprivate func configureReplayWith(_ breadcrumbConverter: SentryReplayBreadcrumbConverter?, screenshotProvider: SentryViewScreenshotProvider?) {
        SentrySDKLog.debug("[Session Replay] Configuring replay")
        if let breadcrumbConverter = breadcrumbConverter {
            currentBreadcrumbConverter = breadcrumbConverter
            sessionReplay?.breadcrumbConverter = breadcrumbConverter
        }

        if let screenshotProvider = screenshotProvider {
            currentScreenshotProvider = screenshotProvider
            sessionReplay?.screenshotProvider = screenshotProvider
        }
    }

    @objc
    fileprivate func setReplayTags(_ tags: [String: Any]) {
        SentrySDKLog.debug("[Session Replay] Setting replay tags: \(tags)")
        sessionReplay?.replayTags = tags
    }

    @objc
    fileprivate func showMaskPreview(_ opacity: Float) {
        SentrySDKLog.debug("[Session Replay] Showing mask preview with opacity: \(opacity)")
        guard crashWrapper.isBeingTraced else {
            SentrySDKLog.debug("[Session Replay] No tracing is active, not showing mask preview")
            return
        }

        guard let window = application?.getWindows()?.first else {
            SentrySDKLog.warning("[Session Replay] No UIWindow available to display preview")
            return
        }

        if previewView == nil {
            previewView = SentryMaskingPreviewView(redactOptions: replayOptions)
        }

        previewView?.opacity = opacity
        previewView?.frame = window.bounds
        if let previewView = previewView {
            window.addSubview(previewView)
        }
    }

    @objc
    fileprivate func hideMaskPreview() {
        SentrySDKLog.debug("[Session Replay] Hiding mask preview")
        previewView?.removeFromSuperview()
        previewView = nil
    }

    // MARK: - Private Helpers

    private func shouldReplayFullSession(_ rate: Double) -> Bool {
        return random.nextNumber() < rate
    }

    private func swizzleApplicationTouch() {
        SentrySDKLog.debug("[Session Replay] Swizzling application touch tracker")
        SentrySwizzleWrapperHelper.swizzleSendEvent { event in
            guard let event = event else { return }
            touchTracker?.trackTouchFrom(event: event)
        }
    }

    private func lastReplayInfo() -> [String: Any]? {
        guard let dir = replayDirectory() else { return nil }
        let lastReplayUrl = dir.appendingPathComponent("replay.last")
        guard let lastReplay = try? Data(contentsOf: lastReplayUrl) else {
            SentrySDKLog.debug("[Session Replay] No last replay info found")
            return nil
        }

        return SentrySerialization.deserializeDictionary(fromJsonData: lastReplay) as? [String: Any]
    }

    //swiftlint:disable function_body_length
    private func resumePreviousSessionReplay(_ event: Event) {
        SentrySDKLog.debug("[Session Replay] Resuming previous session replay")
        guard let dir = replayDirectory(),
              let jsonObject = lastReplayInfo() else {
            SentrySDKLog.debug("[Session Replay] No last replay info found, not resuming previous session replay")
            return
        }

        let replayId: SentryId
        if let replayIdString = jsonObject["replayId"] as? String {
            replayId = SentryId(uuidString: replayIdString)
        } else {
            replayId = SentryId()
        }

        guard let path = jsonObject["path"] as? String else {
            SentrySDKLog.error("[Session Replay] Failed to read path from last replay")
            return
        }

        let lastReplayURL = dir.appendingPathComponent(path)

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
                return
            }
        }

        let resumeReplayMaker = SentryOnDemandReplay(
            withContentFrom: lastReplayURL.path,
            processingQueue: replayProcessingQueue,
            assetWorkerQueue: replayAssetWorkerQueue
        )
        resumeReplayMaker.bitRate = replayOptions.replayBitRate
        resumeReplayMaker.videoScale = replayOptions.sizeScale
        resumeReplayMaker.frameRate = Int(replayOptions.frameRate)

        let beginning: Date
        if hasCrashInfo {
            beginning = Date(timeIntervalSinceReferenceDate: crashInfo.lastSegmentEnd)
        } else {
            guard let oldestFrame = resumeReplayMaker.oldestFrameDate else {
                SentrySDKLog.debug("[Session Replay] No frames to send, dropping replay")
                return
            }
            beginning = oldestFrame
        }

        let end = beginning.addingTimeInterval(duration)

        let videos = resumeReplayMaker.createVideoWith(beginning: beginning, end: end)

        SentrySDKLog.debug("[Session Replay] Created replay with \(videos.count) video segments")

        var currentSegmentId = segmentId
        var currentType = type
        for video in videos {
            captureVideo(video, replayId: replayId, segmentId: currentSegmentId, type: currentType)
            currentSegmentId += 1
            currentType = .session
        }

        var eventContext = event.context ?? [:]
        eventContext["replay"] = ["replay_id": replayId.sentryIdString]
        event.context = eventContext

        try? FileManager.default.removeItem(at: lastReplayURL)
        SentrySDKLog.debug("[Session Replay] Deleted last replay file at path: \(lastReplayURL)")
    }
    //swiftlint:enable function_body_length

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

        try? FileManager.default.removeItem(at: video.path)
    }

    // MARK: - SentrySessionReplayDelegate

    @objc public func sessionReplayShouldCaptureReplayForError() -> Bool {
        return random.nextNumber() <= Double(replayOptions.onErrorSampleRate)
    }

    @objc public func sessionReplayNewSegment(
        replayEvent: SentryReplayEvent,
        replayRecording: SentryReplayRecording,
        videoUrl: URL
    ) {
        SentrySDKLog.debug("[Session Replay] New segment with replay event, eventId: \(replayEvent.eventId), segmentId: \(replayEvent.segmentId)")

        if rateLimits.isRateLimitActive(SentryDataCategory.replay.rawValue) || rateLimits.isRateLimitActive(SentryDataCategory.all.rawValue) {
            SentrySDKLog.debug("[Session Replay] Rate limiting is active for replays. Stopping session replay until next session.")
            rateLimited = true
            stop()
            return
        }
        
        guard let timestamp = replayEvent.timestamp else {
            SentrySDKLog.debug("[Session Replay] Replay event is missing timestamp. Skipping capture.")
            return
        }

//        SentrySDKInternal.currentHub().captureReplayEvent(
//            replayEvent,
//            replayRecording: replayRecording,
//            video: videoUrl
//        )

        sentrySessionReplaySync_updateInfo(
            UInt32(replayEvent.segmentId),
            timestamp.timeIntervalSinceReferenceDate
        )
    }

    @objc public func sessionReplayStarted(replayId: SentryId) {
        SentrySDKLog.debug("[Session Replay] Session replay started with replay id: \(replayId)")
        SentrySDKInternal.currentHub().configureScope { scope in
            scope.replayId = replayId.sentryIdString
        }
    }

    @objc public func breadcrumbsForSessionReplay() -> [Breadcrumb] {
        var result: [Breadcrumb] = []
        SentrySDKInternal.currentHub().configureScope { scope in
            result = scope.breadcrumbs()
        }
        return result
    }

    @objc public func currentScreenNameForSessionReplay() -> String? {
        if let currentScreen = SentrySDKInternal.currentHub().scope.currentScreen {
            return currentScreen
        }
        return application?.relevantViewControllersNames()?.first ?? ""
    }

    // MARK: - SentryReachabilityObserver

    @objc public func connectivityChanged(_ connected: Bool, typeDescription: String) {
        SentrySDKLog.debug("[Session Replay] Connectivity changed to: \(connected ? "connected" : "disconnected"), type: \(typeDescription)")
        if connected {
            sessionReplay?.resume()
        } else {
            sessionReplay?.pauseSessionMode()
        }
    }
}
//swiftlint:enable type_body_length

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
//swiftlint:enable file_length
