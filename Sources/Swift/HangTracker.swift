@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

struct RunLoopIteration {
    let startTime: TimeInterval
    let endTime: TimeInterval
}

protocol HangTracker {
    // The callback must be called on a background thread, because the main thread is blocked
    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID
    
    func removeLateRunLoopObserver(id: UUID)

    // The callback is always called on the main thread
    func addFinishedRunLoopObserver(handler: @escaping (RunLoopIteration) -> Void) -> UUID
    
    func removeFinishedRunLoopObserver(id: UUID)
}
protocol RunLoopObserver { }

extension DefaultHangTracker: HangTracker { }
extension CFRunLoopObserver: RunLoopObserver { }

typealias CreateObserverFunc<T> = (_ allocator: CFAllocator?, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex, _ block: ((T?, CFRunLoopActivity) -> Void)?) -> T?
typealias AddObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void
typealias RemoveObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void

final class DefaultHangTracker<T: RunLoopObserver> {
    init(
        dateProvider: SentryCurrentDateProvider,
        createObserver: @escaping CreateObserverFunc<T>,
        addObserver: @escaping AddObserverFunc<T>,
        removeObserver: @escaping RemoveObserverFunc<T>,
        queue: DispatchQueue = DispatchQueue(label: "io.sentry.runloop-observer-checker")
    ) {
        self.dateProvider = dateProvider
        self.createObserver = createObserver
        self.addObserver = addObserver
        self.removeObserver = removeObserver
        self.queue = queue

#if canImport(UIKit) && !SENTRY_NO_UIKIT && (!swift(>=5.9) || !os(visionOS)) && !os(watchOS)
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
        let expectedFrameDuration = 1.0 / maxFPS
        hangNotifyThreshold = expectedFrameDuration * 1.5
    }
    
    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID {
        let id = UUID()
        queue.async { [weak self] in
            self?.lateRunLoop[id] = handler
            DispatchQueue.main.async {
                self?.startIfNecessary()
            }
        }
        return id
    }
    
    func removeLateRunLoopObserver(id: UUID) {
        queue.async { [weak self] in
            guard let self else { return }
            lateRunLoop.removeValue(forKey: id)
            if lateRunLoop.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    if self?.finishedRunLoop.isEmpty ?? false {
                        self?.stop()
                    }
                }
            }
        }
    }
    
    func addFinishedRunLoopObserver(handler: @escaping (RunLoopIteration) -> Void) -> UUID {
        let id = UUID()
        finishedRunLoop[id] = handler
        startIfNecessary()
        return id
    }
    
    func removeFinishedRunLoopObserver(id: UUID) {
        finishedRunLoop.removeValue(forKey: id)
        if finishedRunLoop.isEmpty {
            queue.async { [weak self] in
                if self?.lateRunLoop.isEmpty ?? false {
                    DispatchQueue.main.async {
                        if self?.finishedRunLoop.isEmpty ?? false {
                            self?.stop()
                        }
                    }
                }
            }
        }
    }
    
    // This queue is used to detect main thread hangs, they need to be detected on a background thread
    // since the main thread is hanging.
    private let queue: DispatchQueue
    private let hangNotifyThreshold: TimeInterval
    private let dateProvider: SentryCurrentDateProvider
    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>
    
    // MARK: Main queue

    private var observer: T?
    private var finishedRunLoop = [UUID: (RunLoopIteration) -> Void]()
    private var semaphore: DispatchSemaphore?
    private var loopStartTime: TimeInterval?
    
    private func startIfNecessary() {
        guard observer == nil else {
            // Already running
            return
        }

        let observer = createObserver(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue, true, CFIndex(INT_MAX)) { [weak self] _, activity in
            guard let self else { return }

            let currentTime = dateProvider.systemUptime()
            switch activity {
            case .beforeWaiting:
                semaphore?.signal()
                if let loopStartTime {
                    for handler in finishedRunLoop.values {
                        handler(RunLoopIteration(startTime: loopStartTime, endTime: currentTime))
                    }
                }
            case .afterWaiting:
                let started = currentTime
                loopStartTime = currentTime
                let localSemaphore = DispatchSemaphore(value: 0)
                semaphore = localSemaphore
                queue.async { [weak self] in
                    self?.waitForHang(semaphore: localSemaphore, started: started, isStarting: true)
                }
            default:
                fatalError()
            }
        }
        self.observer = observer
        addObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    private func stop() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let observer else {
            return
        }
        removeObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = nil
    }
    
    // MARK: Background queue
    
    private var lateRunLoop = [UUID: (UUID, TimeInterval) -> Void]()
    private var hangId = UUID()
    
    private func waitForHang(semaphore: DispatchSemaphore, started: TimeInterval, isStarting: Bool) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(hangNotifyThreshold * 1_000))
        let result = semaphore.wait(timeout: timeout)
        switch result {
        case .timedOut:
            if isStarting {
                hangId = UUID()
            }
            lateRunLoop.values.forEach { $0(hangId, dateProvider.systemUptime() - started) }
            waitForHang(semaphore: semaphore, started: started, isStarting: false)
        case .success:
            break
        }
    }
}

extension DefaultHangTracker where T == CFRunLoopObserver {
    convenience init(dateProvider: SentryCurrentDateProvider) {
        self.init(
            dateProvider: dateProvider,
            createObserver: CFRunLoopObserverCreateWithHandler,
            addObserver: CFRunLoopAddObserver,
            removeObserver: CFRunLoopRemoveObserver
        )
    }
}
