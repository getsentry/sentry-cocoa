@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

final class RunLoopObserver {

    private let dateProvider: SentryCurrentDateProvider
    private let threadInspector: ThreadInspector
    private let debugImageCache: DebugImageCache
    private let fileManager: SentryFileManager

    init(
        dateProvider: SentryCurrentDateProvider,
        threadInspector: ThreadInspector,
        debugImageCache: DebugImageCache,
        fileManager: SentryFileManager,
        minHangTime: TimeInterval) {
        self.dateProvider = dateProvider
        self.threadInspector = threadInspector
        self.debugImageCache = debugImageCache
        self.fileManager = fileManager
        self.lastFrameTime = 0
        self.minHangTime = minHangTime
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        var maxFPS = 60.0
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }
            maxFPS = Double(window?.screen.maximumFramesPerSecond ?? 60)
        } else {
            maxFPS = Double(UIScreen.main.maximumFramesPerSecond)
        }
#else
        let maxFPS: Double = 60.0
        #endif
        expectedFrameDuration = 1.0 / maxFPS
        thresholdForFrameStacktrace = expectedFrameDuration * 0.5
        // TODO: Check for stored app hang
    }
    
    // This queue is used to detect main thread hangs, they need to be detected on a background thread
    // since the main thread is hanging.
    private let queue = DispatchQueue(label: "io.sentry.runloop-observer-checker")
    private let minHangTime: TimeInterval
    private let expectedFrameDuration: TimeInterval
    private let thresholdForFrameStacktrace: TimeInterval
    
    // MARK: Main queue

    private var semaphore = DispatchSemaphore(value: 0)
    private var lastFrameTime: TimeInterval
    private var running = false
    private var frameStatistics = [(startTime: TimeInterval, delayTime: TimeInterval)]()
    // Keeps track of how long the current hang has been running for
    // Set to nil after the current hang ends
    private var maxHangTime: TimeInterval?
    
    func start() {
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue | CFRunLoopActivity.beforeSources.rawValue, true, CFIndex(INT_MAX)) { [weak self] _, activity in
            guard let self else { return }

            let started = updateFrameStatistics()
            switch activity {
            case .beforeWaiting:
                running = false
            case .afterWaiting, .beforeSources:
                semaphore = DispatchSemaphore(value: 0)
                running = true
                let localSemaphore = semaphore
                queue.async { [weak self] in
                    self?.waitForHang(semaphore: localSemaphore, started: started, isStarting: true)
                }
            default:
                fatalError()
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    private func updateFrameStatistics() -> Double {
        dispatchPrecondition(condition: .onQueue(.main))

        let currentTime = dateProvider.systemUptime()
        // Only consider frames that were within 2x the minHangTime
        frameStatistics = frameStatistics.filter { $0.startTime > currentTime - minHangTime * 2 }
        
        semaphore.signal()
        if running {
            let frameDuration = currentTime - lastFrameTime
            let frameDelay = frameDuration - expectedFrameDuration
            // A hang is characterized by the % of a time period that the app is rendering late frames
            // We use 50% of `minHangTime * 2` as the threshold for reporting a hang.
            // Once this threshold is crossed, any frame that was > 50% late is considered a hanging frame.
            // If a single frames delay is > minHangTime, it is considered a "fullyBlocking" hang.
            if frameDelay > 0 {
                frameStatistics.append((startTime: lastFrameTime, delayTime: frameDelay))
            }
            let totalTime = frameStatistics.map({ $0.delayTime }).reduce(0, +)
            let type: SentryANRType = frameStatistics.count > 0 ? .nonFullyBlocking : .fullyBlocking
            if totalTime > minHangTime {
                print("[HANG] Hang detected \(totalTime)")
                let maxTime = max(maxHangTime ?? 0, totalTime)
                maxHangTime = maxTime
                // Update on disk hang
                queue.async { [weak self] in
                    guard let self, let threads = threads, !threads.isEmpty else { return }
                    let event = makeEvent(duration: maxTime, threads: threads, type: type)
                    fileManager.storeAppHang(event)
                }
            } else {
                if let maxHangTime {
                    // The hang has ended
                    print("[HANG] Hang reporting \(maxHangTime)")
                    // Note: A non fully blocking hang always has multiple stacktraces
                    // because it is composed of multpile delayed frames. Each delayed frame has a stacktrace.
                    // We only support sending one stacktrace per event so we take the most recent one.
                    // Another option would be to generate one event for each delayed frame in the
                    // non fully blocking hang. Maybe we will eventually support something like
                    // "scroll hitches" and report each time a frame is dropped rather than an
                    // overal hang event with just one stacktrace.
                    queue.async { [weak self] in
                        guard let self, let threads = threads, !threads.isEmpty else { return }
                        let event = makeEvent(duration: maxHangTime, threads: threads, type: type)
                        SentrySDK.capture(event: event)
                    }
                }
                maxHangTime = nil
            }
        }
        lastFrameTime = currentTime
        return currentTime
    }
    
    // MARK: Background queue
    
    private var blockingDuration: TimeInterval?
    private var threads: [SentryThread]?
    
    private func waitForHang(semaphore: DispatchSemaphore, started: TimeInterval, isStarting: Bool) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int((expectedFrameDuration + thresholdForFrameStacktrace) * 1_000))
        let result = semaphore.wait(timeout: timeout)
        switch result {
        case .timedOut:
            semaphore.signal()
            print("[HANG] Timeout, hang detected")
            continueHang(started: started, isStarting: isStarting)
            waitForHang(semaphore: semaphore, started: started, isStarting: false)
        case .success:
            break
        }
    }
    
    // TODO: Only write hang if it's long enough
    // TODO: Need to clear hang details after the hang ends
    // Problem: If we are detecting a multiple runloop hang, which then turns into a single long hang
    // we might want to add the total time of that long hang to what is on disk from the multiple runloop hang
    // Or we could not do that and just say we only overwrite what is on disk if the hang exceeds the time
    // of the multiple runloop hang.
    // Could have two paths, fullyBlocking only used when the semaphore times out, we keep tracking in memory until
    // it exceeds the threshold then we write to disk.
    // Non fully blocking only writes when the runloop finishes if it exceeds the threshold.
    // Sampled stacktrace should be kept separate from time, because time for nonFullyBlocking is kep on main thread
    // time for fullyBlocking is kept on background thread
    
    // TODO: Not using should sample
    private func continueHang(started: TimeInterval, isStarting: Bool) {
        dispatchPrecondition(condition: .onQueue(queue))

        if isStarting {
            // A hang lasts a while, but we only support showing the stacktrace when it was first detected
            threads = threadInspector.getCurrentThreadsWithStackTrace()
            threads?.forEach { $0.current = false }
            threads?[0].current = true
        }
        let duration = dateProvider.systemUptime() - started
        blockingDuration = duration
        if let threads, !threads.isEmpty, duration > minHangTime {
            // Hangs detected in the background are always fully blocking
            // Otherwise we'd be detecting them on the main thread.
            fileManager.storeAppHang(makeEvent(duration: duration, threads: threads, type: .fullyBlocking))
        }
        
    }
    
    // Safe to call from any thread
    private func makeEvent(duration: TimeInterval, threads: [SentryThread], type: SentryANRType) -> Event {
        var event = Event()
        SentryLevelBridge.setBreadcrumbLevelOn(event, level: SentryLevel.error.rawValue)
        let exceptionType = SentryAppHangTypeMapper.getExceptionType(anrType: type)
        let exception = Exception(value: String(format: "App hanging for %.3f seconds.", duration), type: exceptionType)
        let mechanism = Mechanism(type: "AppHang")
        exception.mechanism = mechanism
        exception.stacktrace = threads[0].stacktrace
        exception.stacktrace?.snapshot = true
        exception.stacktrace?.snapshot = true
        event.exceptions = [exception]
        event.threads = threads
        event.debugMeta = debugImageCache.getDebugImagesFromCacheFor(threads: event.threads)
        SentryDependencyContainerSwiftHelper.applyScope(to: event)
        return event
    }
}

@objc
@_spi(Private) public final class RunLoopObserverObjcBridge: NSObject {

    private let observer: RunLoopObserver

    @objc public init(
        dateProvider: SentryCurrentDateProvider,
        threadInspector: ThreadInspector,
        debugImageCache: DebugImageCache,
        fileManager: SentryFileManager) {
        observer = RunLoopObserver(
            dateProvider: dateProvider,
            threadInspector: threadInspector,
            debugImageCache: debugImageCache,
            fileManager: fileManager,
            minHangTime: 2)
    }
    
    @objc public func start() {
        observer.start()
    }
}

@objc @_spi(Private) public protocol ThreadInspector {
    func getCurrentThreadsWithStackTrace() -> [SentryThread]
}

@objc @_spi(Private) public protocol DebugImageCache {
    func getDebugImagesFromCacheFor(threads: [SentryThread]?) -> [DebugMeta]
}
