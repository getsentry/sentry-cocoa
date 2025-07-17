@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

// A hang is parameterized by the its minimum duration, HangDuration, and is defined by a period of time lasting longer than HangDuration*2 when the delay
// of all frames started during that time sums to more than HangDuration. If there is only one frame during this time that is delayed then it is a "fullyBlocking"
// hang, otherwise it is a "nonFullyBlocking" hang.
//
// We measure late frames using a runloop observer. Any frame that is more than 50% delayed has its stacktrace sampled once, when we first detect it is delayed.
// After the hang ends (or the app restarts in the case of fatal hangs) the most recently recorded stacktrace is used to report the hang. Since a hang is not one
// stacktrace, like a crash, but rather a period of time, it would make sense to talk about a flamegraph sampled during the hang but the API does not support this.
// Note that stacktraces are always sampled from a background thread, since it’s the main thread that gets sampled.
//
// There are two ways we trigger saving hang data. One is on the main thread, when the hang is over. When each frame finishes rendering we collect its delay and
// if the sum of delays during the last HangDuration*2 is greather than the threshold, we report the last stack trace as a hang. The other way is on a background
// thread. Once a frame is delayed more than 50% we sample the thread and start tracking it. If the total delay becomes more than our threshold the event
// is recorded. If the hang never ends (thus transfering us back to the previous main thread case) then the hang is saved on the filesystem and
// sent as a fatal hang the next time the app is launched.
final class HangTracker {
    
    static let SentryANRMechanismDataAppHangDuration = "app_hang_duration"

    private let dateProvider: SentryCurrentDateProvider
    private let threadInspector: ThreadInspector
    private let debugImageCache: DebugImageCache
    private let fileManager: SentryFileManager
    private let crashWrapper: CrashWrapper

    init(
        dateProvider: SentryCurrentDateProvider,
        threadInspector: ThreadInspector,
        debugImageCache: DebugImageCache,
        fileManager: SentryFileManager,
        crashWrapper: CrashWrapper,
        minHangTime: TimeInterval) {
        self.dateProvider = dateProvider
        self.threadInspector = threadInspector
        self.debugImageCache = debugImageCache
        self.fileManager = fileManager
        self.crashWrapper = crashWrapper
        self.lastFrameTime = 0
        self.minHangTime = minHangTime
#if canImport(UIKit) && !SENTRY_NO_UIKIT && !os(visionOS) && !os(watchOS)
        var maxFPS = 60.0
            if #available(iOS 13.0, tvOS 13.0, *) {
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
        captureStoredAppHang()
    }
    
    // This queue is used to detect main thread hangs, they need to be detected on a background thread
    // since the main thread is hanging.
    private let queue = DispatchQueue(label: "io.sentry.runloop-observer-checker")
    private let minHangTime: TimeInterval
    private let expectedFrameDuration: TimeInterval
    private let thresholdForFrameStacktrace: TimeInterval
    
    // MARK: Main queue

    private var observer: CFRunLoopObserver?
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
        self.observer = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    func stop() {
        guard let observer else { return }

        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
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
                SentrySDKLog.debug("Detected app hang for \(totalTime) seconds")
                let maxTime = max(maxHangTime ?? 0, totalTime)
                maxHangTime = maxTime
                // Update on disk hang
                queue.async { [weak self] in
                    guard let self, let threads = threads, !threads.isEmpty else { return }
                    let event = makeEvent(duration: maxTime, threads: threads, type: type, addMechanismData: true)
                    fileManager.storeAppHang(event)
                }
            } else {
                if let maxHangTime {
                    // The hang has ended
                    SentrySDKLog.debug("Reporting app hang with \(maxHangTime) seconds")
                    // Note: A non fully blocking hang always has multiple stacktraces
                    // because it is composed of multpile delayed frames. Each delayed frame has a stacktrace.
                    // We only support sending one stacktrace per event so we take the most recent one.
                    // Another option would be to generate one event for each delayed frame in the
                    // non fully blocking hang. Maybe we will eventually support something like
                    // "scroll hitches" and report each time a frame is dropped rather than an
                    // overal hang event with just one stacktrace.
                    queue.async { [weak self] in
                        guard let self, let threads = threads, !threads.isEmpty else { return }
                        let event = makeEvent(duration: maxHangTime, threads: threads, type: type, addMechanismData: false)
                        SentrySDK.capture(event: event)
                    }
                }
                maxHangTime = nil
            }
        }
        lastFrameTime = currentTime
        return currentTime
    }
    
    func captureStoredAppHang() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self, let event = fileManager.readAppHangEvent() else { return }
            
            fileManager.deleteAppHangEvent()
            if crashWrapper.crashedLastLaunch {
                // The app crashed during an ongoing app hang. Capture the stored app hang as it is.
                // We already applied the scope. We use an empty scope to avoid overwriting exising
                // fields on the event.
                SentrySDK.capture(event: event, scope: Scope())
            } else {
                // Fatal App Hang
                // We can't differ if the watchdog or the user terminated the app, because when the main
                // thread is blocked we don't receive the applicationWillTerminate notification. Further
                // investigations are required to validate if we somehow can differ between watchdog or
                // user terminations; see https://github.com/getsentry/sentry-cocoa/issues/4845.
                guard let exceptions = event.exceptions, let exception = exceptions.first, exceptions.count == 1 else {
                    SentrySDKLog.warning("The stored app hang event is expected to have exactly one exception, so we don't capture it.")
                    return
                }
                
                SentryLevelBridge.setBreadcrumbLevelOn(event, level: SentryLevel.fatal.rawValue)
                event.exceptions?.first?.mechanism?.handled = false
                let fatalExceptionType = SentryAppHangTypeMapper.getFatalExceptionType(nonFatalErrorType: exception.type)
                event.exceptions?.first?.type = fatalExceptionType
                
                var mechanismData = exception.mechanism?.data
                let durationInfo = mechanismData?[Self.SentryANRMechanismDataAppHangDuration] as? String ?? "over \(minHangTime) seconds"
                mechanismData?.removeValue(forKey: Self.SentryANRMechanismDataAppHangDuration)
                event.exceptions?.first?.value = "The user or the OS watchdog terminated your app while it blocked the main thread for \(durationInfo)"
                event.exceptions?.first?.mechanism?.data = mechanismData
                SentryDependencyContainerSwiftHelper.captureFatalAppHang(event)
                
            }
        }
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

    private func continueHang(started: TimeInterval, isStarting: Bool) {
        dispatchPrecondition(condition: .onQueue(queue))

        if isStarting {
            // A hang lasts a while, we show the stacktrace when it was first detected
            threads = threadInspector.getCurrentThreadsWithStackTrace()
            threads?.forEach { $0.current = false }
            threads?[0].current = true
        }
        let duration = dateProvider.systemUptime() - started
        blockingDuration = duration
        if let threads, !threads.isEmpty, duration > minHangTime {
            // Hangs detected in the background are always fully blocking
            // Otherwise we'd be detecting them on the main thread.
            fileManager.storeAppHang(makeEvent(duration: duration, threads: threads, type: .fullyBlocking, addMechanismData: true))
        }
        
    }
    
    // Safe to call from any thread
    private func makeEvent(duration: TimeInterval, threads: [SentryThread], type: SentryANRType, addMechanismData: Bool) -> Event {
        let event = Event()
        SentryLevelBridge.setBreadcrumbLevelOn(event, level: SentryLevel.error.rawValue)
        let exceptionType = SentryAppHangTypeMapper.getExceptionType(anrType: type)
        let exception = Exception(value: String(format: "App hanging for %.3f seconds.", duration), type: exceptionType)
        let mechanism = Mechanism(type: "AppHang")
        // We only temporarily store the app hang duration info, so we can change the error message
        // when either sending a normal or fatal app hang event. Otherwise, we would have to rely on
        // string parsing to retrieve the app hang duration info from the error message.
        if addMechanismData {
            mechanism.data = [Self.SentryANRMechanismDataAppHangDuration: "\(duration) seconds"]
        }
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
@_spi(Private) public final class HangTrackerObjcBridge: NSObject {

    private let observer: HangTracker

    @objc public init(
        dateProvider: SentryCurrentDateProvider,
        threadInspector: ThreadInspector,
        debugImageCache: DebugImageCache,
        fileManager: SentryFileManager,
        crashWrapper: CrashWrapper) {
        observer = HangTracker(
            dateProvider: dateProvider,
            threadInspector: threadInspector,
            debugImageCache: debugImageCache,
            fileManager: fileManager,
            crashWrapper: crashWrapper,
            minHangTime: 2)
    }
    
    @objc public func start() {
        observer.start()
    }
    
    @objc public func stop() {
        observer.stop()
    }
}

@objc @_spi(Private) public protocol ThreadInspector {
    func getCurrentThreadsWithStackTrace() -> [SentryThread]
}

@objc @_spi(Private) public protocol DebugImageCache {
    func getDebugImagesFromCacheFor(threads: [SentryThread]?) -> [DebugMeta]
}

@objc @_spi(Private) public protocol CrashWrapper {
    var crashedLastLaunch: Bool { get }
}
