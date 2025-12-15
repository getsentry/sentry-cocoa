extension SentryReplayOptions {
    var shouldEnable: Bool {
        onErrorSampleRate > 0 || sessionSampleRate > 0
    }
}

final class SentrySessionReplayIntegration: NSObject, SwiftIntegration {
    
    static let currentReplayDir = "replay.current"
    static let lastReplayDir = "replay.last"

    typealias Dependencies = SentryDependencyContainer
    
    let replayOptions: SentryReplayOptions
    let experimentalOptions: SentryExperimentalOptions
    let rateLimits: RateLimits
    let dateProvider: SentryCurrentDateProvider
    let viewPhotographer: SentryViewPhotographer
    let touchTracker: SentryTouchTracker?
    let notificationCenter: SentryNSNotificationCenterWrapper
    let environmentChecker: SentrySessionReplayEnvironmentCheckerProvider
    let replayAssetWorkerQueue: SentryDispatchQueueWrapper
    let replayProcessingQueue: SentryDispatchQueueWrapper
    let fileManager: SentryFileManager?

    init?(with options: Options, dependencies: Dependencies) {
        guard options.sessionReplay.shouldEnable else {
            SentrySDKLog.debug("Not going to enable \(Self.name).")
            return nil
        }
        guard SentrySessionReplay.shouldEnableSessionReplay(environmentChecker: dependencies.sessionReplayEnvironmentChecker, experimentalOptions: options.experimental) else {
            return nil
        }

        
        replayOptions = options.sessionReplay
        experimentalOptions = options.experimental
        rateLimits = dependencies.rateLimits
        dateProvider = dependencies.dateProvider
        
        var viewRenderer: SentryViewRenderer
        if replayOptions.enableViewRendererV2 {
            SentrySDKLog.debug("[Session Replay] Setting up view renderer v2, fast view rendering: \(replayOptions.enableFastViewRendering)")
            viewRenderer = SentryViewRendererV2(enableFastViewRendering: replayOptions.enableFastViewRendering)
        } else {
            SentrySDKLog.debug("[Session Replay] Setting up default view renderer")
            viewRenderer = SentryDefaultViewRenderer()
        }
        
        // We are using the flag for the view renderer V2 also for the mask renderer V2, as it would
        // just introduce another option without affecting the SDK user experience.
        viewPhotographer = SentryViewPhotographer(renderer: viewRenderer, redactOptions: replayOptions, enableMaskRendererV2: replayOptions.enableViewRendererV2)

        if options.enableSwizzling {
            SentrySDKLog.debug(
                "[Session Replay] Setting up touch tracker, scale: \(replayOptions.sizeScale)")
            touchTracker = SentryTouchTracker(dateProvider: dateProvider, scale: replayOptions.sizeScale)
            swizzleApplicationTouch()
        }

        notificationCenter = dependencies.notificationCenterWrapper
        environmentChecker = dependencies.sessionReplayEnvironmentChecker
        fileManager = dependencies.fileManager

        // We use the dispatch queue provider as a factory to create the queues, but store the queues
        // directly in this instance, so they get deallocated when the integration is deallocated.
        let dispatchQueueProvider = dependencies.dispatchFactory

        // The asset worker queue is used to work on video and frames data.
        // Use a relative priority of -1 to make it lower than the default background priority.
        replayAssetWorkerQueue = dispatchQueueProvider.createUtilityQueue("io.sentry.session-replay.asset-worker", relativePriority: -1)

        // The dispatch queue is used to asynchronously wait for the asset worker queue to finish its
        // work. To avoid a deadlock, the priority of the processing queue must be lower than the asset
        // worker queue. Use a relative priority of -2 to make it lower than the asset worker queue.
        replayProcessingQueue = dispatchQueueProvider.createUtilityQueue("io.sentry.session-replay.processing", relativePriority: -2)

        moveCurrentReplay()
        cleanUp()

//        [SentrySDKInternal.currentHub registerSessionListener:self];

//        __weak SentrySessionReplayIntegration *weakSelf = self;
//        [SentryDependencyContainer.sharedInstance.globalEventProcessor
//            addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
//                if (weakSelf == nil) {
//                    SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
//                    return event;
//                }
//
//                if (event.isFatalEvent) {
//                    [weakSelf resumePreviousSessionReplay:event];
//                } else {
//                    [weakSelf.sessionReplay captureReplayForEvent:event];
//                }
//                return event;
//            }];
//
//        [SentryDependencyContainer.sharedInstance.reachability addObserver:self];
    }
    
    func swizzleApplicationTouch() {
        SentrySDKLog.debug("[Session Replay] Swizzling application touch tracker")
        
//        SentrySwizzle
//        
//            SEL selector = NSSelectorFromString(@"sendEvent:");
//            SentrySwizzleInstanceMethod([UIApplication class], selector, SentrySWReturnType(void),
//                SentrySWArguments(UIEvent * event), SentrySWReplacement({
//                    [_touchTracker trackTouchFromEvent:event];
//                    SentrySWCallOriginal(event);
//                }),
//                SentrySwizzleModeOncePerClass, (void *)selector);
    }
    
    func replayDirectory() -> NSURL? {
        guard let sentryPath = fileManager?.sentryPath else {
            return nil
        }

        let dir = URL(fileURLWithPath: sentryPath) as NSURL
        return dir.appendingPathComponent("replay") as? NSURL
    }
    
    func moveCurrentReplay() {
        SentrySDKLog.debug("[Session Replay] Moving current replay")
        let fileManager = FileManager.default

        let path = replayDirectory()
        let current = path?.appendingPathComponent(Self.currentReplayDir) as? NSURL
        let currentPath = current?.path
        let last = path?.appendingPathComponent(Self.lastReplayDir) as? NSURL
        let lastPath = last?.path

        NSError *error;
        if ([fileManager fileExistsAtPath:lastPath]) {
            SENTRY_LOG_DEBUG(@"[Session Replay] Removing last replay file at path: %@", last);
            if ([NSFileManager.defaultManager removeItemAtURL:last error:&error] == NO) {
                SENTRY_LOG_ERROR(
                    @"[Session Replay] Could not delete last replay file, reason: %@", error);
                return;
            }
            SENTRY_LOG_DEBUG(@"[Session Replay] Removed last replay file at path: %@", last);
        } else {
            SENTRY_LOG_DEBUG(@"[Session Replay] No last replay file to remove at path: %@", last);
        }

        if ([fileManager fileExistsAtPath:currentPath]) {
            SENTRY_LOG_DEBUG(
                @"[Session Replay] Moving current replay file at path: %@ to: %@", current, last);
            if ([fileManager moveItemAtURL:current toURL:last error:&error] == NO) {
                SENTRY_LOG_ERROR(@"[Session Replay] Could not move replay file, reason: %@", error);
                return;
            }
            SENTRY_LOG_DEBUG(@"[Session Replay] Moved current replay file at path: %@", current);
        } else {
            SENTRY_LOG_DEBUG(@"[Session Replay] No current replay file to move at path: %@", current);
        }
    }
    
    deinit {
        uninstall()
    }
    
    func uninstall() {
        
    }
    
    static var name: String {
        "SentrySessionReplayIntegration"
    }
}
