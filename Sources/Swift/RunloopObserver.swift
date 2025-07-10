@_implementationOnly import _SentryPrivate

protocol ThreadInspector {
    func getCurrentThreadsWithStackTrace() -> [SentryThread]
}

@objc @_spi(Private) public protocol DebugImageCache {
    func getDebugImagesFromCache(for threads: [SentryThread]?) -> [DebugMeta]
}

protocol ThreadInspectorProviding {
    var threadInspector: ThreadInspector { get }
}

protocol SentryCurrentDateProviding {
    var dateProvider: SentryCurrentDateProvider { get }
}

protocol DebugImageCacheProviding {
    var debugImageCache: DebugImageCache { get }
}

typealias RunLoopObserverDependencies = SentryCurrentDateProviding & ThreadInspectorProviding & DebugImageCacheProviding

final class RunloopObserver {
    let dependencies: RunLoopObserverDependencies
    init(dependencies: RunLoopObserverDependencies, minHangTime: TimeInterval) {
        self.dependencies = dependencies
        self.lastFrameTime = 0
        self.minHangTime = minHangTime
    }
    
    // This queue is used to detect main thread hangs, they need to be detected on a background thread
    // since the main thread is hanging.
    let queue = DispatchQueue(label: "io.sentry.runloop-observer-checker")
    var semaphore = DispatchSemaphore(value: 0)
    let minHangTime: TimeInterval
    
    // MARK: Main queue

    var lastFrameTime: TimeInterval
    var running = false
    var frameStatistics = [(startTime: TimeInterval, delayTime: TimeInterval)]()
    
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
                let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(minHangTime * 1_000))
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
                // print("[HANG] Woken up")
            default:
                fatalError()
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    func updateFrameStatistics() {
        dispatchPrecondition(condition: .onQueue(.main))

        let currentTime = dependencies.dateProvider.systemUptime()
        defer {
            lastFrameTime = currentTime
        }
        // Only consider frames that were within 2x the minHangTime
        frameStatistics = frameStatistics.filter { $0.startTime > currentTime - minHangTime * 2 }
        
        semaphore.signal()
        if running {
            let expectedFrameTime = lastFrameTime + 1.0 / 60.0
            let frameDelay = currentTime - expectedFrameTime
            if frameDelay > minHangTime {
                print("[HANG] Hang detected \(frameDelay)s")
                queue.async { [weak self] in
                    self?.recordHang(duration: frameDelay)
                }
                frameStatistics.removeAll()
            } else if frameDelay > 0 {
                frameStatistics.append((startTime: lastFrameTime, delayTime: frameDelay))
            }
            let totalTime = frameStatistics.map({ $0.delayTime }).reduce(0, +)
            if totalTime > minHangTime * 0.99 {
                print("[HANG] Detected non-blocking hang")
                // TODO: Keep on recording until blocking period is over (or some max time)
                // TODO: Get stacktraces from when the individual blocking events occured
                // TODO: Send each event
            }
        }
    }
    
    // MARK: Background queue

    var threads: [SentryThread]?
    
    func hangStarted() {
        dispatchPrecondition(condition: .onQueue(queue))

        // TODO: Write to disk to record fatal hangs on app start

        // Record threads at start of hang
        threads = dependencies.threadInspector.getCurrentThreadsWithStackTrace()
    }
    
    func recordHang(duration: TimeInterval) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard let threads, !threads.isEmpty else {
            return
        }
        
        let event = Event()
        SentryLevelBridge.setBreadcrumbLevelOn(event, level: SentryLevel.error.rawValue)
        let exceptionType = SentryAppHangTypeMapper.getExceptionType(anrType: .fullyBlocking)
        let exception = Exception(value: "App hanging for \(duration) seconds.", type: exceptionType)
        let mechanism = Mechanism(type: "AppHang")
        exception.mechanism = mechanism
        exception.stacktrace = threads[0].stacktrace
        exception.stacktrace?.snapshot = true

        threads.forEach { $0.current = false }
        threads[0].current = true

        event.exceptions = [exception]
        event.threads = threads

        event.debugMeta = dependencies.debugImageCache.getDebugImagesFromCache(for: event.threads)
        SentrySDK.capture(event: event)
    }
}

@objc
@_spi(Private) public final class RunLoopObserverObjcBridge: NSObject {
    @_spi(Private) @objc public init(dependencies: SentryDependencyScope) {
        observer = RunloopObserver(dependencies: dependencies, minHangTime: 2)
        observer.start()
    }
    let observer: RunloopObserver
    
}

@objc
@_spi(Private) public class SentryDependencyScope: NSObject, SentryCurrentDateProviding, DebugImageCacheProviding, ThreadInspectorProviding {
    @objc @_spi(Private) public init(options: Options, debugImageCache: DebugImageCache) {
        self.threadInspector = SentryThreadInspector(options: options)
        self.debugImageCache = debugImageCache
    }

    @_spi(Private) @objc public let dateProvider: SentryCurrentDateProvider = SentryDefaultCurrentDateProvider()
    let threadInspector: ThreadInspector
    let debugImageCache: DebugImageCache
}

extension SentryThreadInspector: ThreadInspector { }
