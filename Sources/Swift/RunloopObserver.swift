@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

final class RunLoopObserver {

    private let dateProvider: SentryCurrentDateProvider
    private let threadInspector: ThreadInspector
    private let debugImageCache: DebugImageCache

    init(
        dateProvider: SentryCurrentDateProvider,
        threadInspector: ThreadInspector,
        debugImageCache: DebugImageCache,
        minHangTime: TimeInterval) {
        self.dateProvider = dateProvider
        self.threadInspector = threadInspector
        self.debugImageCache = debugImageCache
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

            switch activity {
            case .beforeWaiting:
                updateFrameStatistics()
                running = false
            case .afterWaiting, .beforeSources:
                updateFrameStatistics()
                semaphore = DispatchSemaphore(value: 0)
                running = true
                let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int((expectedFrameDuration + thresholdForFrameStacktrace) * 1_000))
                let localSemaphore = semaphore
                queue.async { [weak self] in
                    let result = localSemaphore.wait(timeout: timeout)
                    switch result {
                    case .timedOut:
                        print("[HANG] Timeout, hang detected")
                        self?.hangStarted()
                    case .success:
                        break
                    }
                }
            default:
                fatalError()
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    private func updateFrameStatistics() {
        dispatchPrecondition(condition: .onQueue(.main))

        let currentTime = dateProvider.systemUptime()
        defer {
            lastFrameTime = currentTime
        }
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
            if totalTime > minHangTime {
                print("[HANG] Hang detected \(totalTime)")
                maxHangTime = max(maxHangTime ?? 0, totalTime)
                // print("[HANG] Hang max \(maxHangTime ?? 0)")
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
                    let type: SentryANRType = frameStatistics.count > 0 ? .nonFullyBlocking : .fullyBlocking
                    queue.async { [weak self] in
                        self?.recordHang(duration: maxHangTime, type: type)
                    }
                }
                maxHangTime = nil
            }
        }
    }
    
    // MARK: Background queue

    private var threads: [SentryThread]?
    
    private func hangStarted() {
        dispatchPrecondition(condition: .onQueue(queue))

        // TOD: Write to disk to record fatal hangs on app start
        // Record threads when the hang is first detected
        threads = threadInspector.getCurrentThreadsWithStackTrace()
    }
    
    private func recordHang(duration: TimeInterval, type: SentryANRType) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard let threads, !threads.isEmpty else {
            return
        }
        
        let event = Event()
        SentryLevelBridge.setBreadcrumbLevelOn(event, level: SentryLevel.error.rawValue)
        let exceptionType = SentryAppHangTypeMapper.getExceptionType(anrType: type)
        let exception = Exception(value: String(format: "App hanging for %.3f seconds.", duration), type: exceptionType)
        let mechanism = Mechanism(type: "AppHang")
        exception.mechanism = mechanism
        exception.stacktrace = threads[0].stacktrace
        exception.stacktrace?.snapshot = true

        threads.forEach { $0.current = false }
        threads[0].current = true

        event.exceptions = [exception]
        event.threads = threads

        event.debugMeta = debugImageCache.getDebugImagesFromCacheFor(threads: event.threads)
        SentrySDK.capture(event: event)
    }
}

@objc
@_spi(Private) public final class RunLoopObserverObjcBridge: NSObject {

    private let observer: RunLoopObserver

    @objc public init(
        dateProvider: SentryCurrentDateProvider,
        threadInspector: ThreadInspector,
        debugImageCache: DebugImageCache) {
        observer = RunLoopObserver(dateProvider: dateProvider,
                                           threadInspector: threadInspector,
                                           debugImageCache: debugImageCache, minHangTime: 2)
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
