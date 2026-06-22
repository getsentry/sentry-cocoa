// Only gated for these platforms so we can use Combine
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Combine

struct HangData {
    let duration: TimeInterval
    let stacktraces: [SentryStacktrace]
}

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol AppHangDetection {
    var onHangDetected: PassthroughSubject<HangData, Never> { get }
}
extension DefaultAppHangDetection: AppHangDetection {}

protocol AppHangDependencies {
    var hangTracker: HangTracker { get }
    var threadInspector: SentryThreadInspector { get }
}
extension SentryDependencyContainer: AppHangDependencies { }

protocol AppHangDetectionOptions {
    var appHangThreshold: TimeInterval { get }
}
extension DefaultAppHangDetectionOptions: AppHangDetectionOptions {}
#else
typealias AppHangDetection = DefaultAppHangDetection
typealias AppHangDependencies = SentryDependencyContainer
typealias AppHangDetectionOptions = DefaultAppHangDetectionOptions
#endif

struct DefaultAppHangDetectionOptions {
    var appHangThreshold: TimeInterval
}

class DefaultAppHangDetection<Dependencies: AppHangDependencies, Options: AppHangDetectionOptions> {
    private let hangTracker: HangTracker
    private let threadInspector: SentryThreadInspector
    private let options: Options

    private var observer: HangTrackerObserver?
    private var hitchDurationCounter: TimeInterval = 0
    private var stacktraces: [SentryStacktrace] = []

    public let onHangDetected = PassthroughSubject<HangData, Never>()

    init(dependencies: Dependencies, options: Options) {
        self.hangTracker = dependencies.hangTracker
        self.threadInspector = dependencies.threadInspector
        self.options = options

        observer = hangTracker.addOngoingHangObserver { [weak self] duration, ongoing in
            guard let strongSelf = self else { return }
            strongSelf.processHitch(duration: duration, isOngoing: ongoing)
        }
    }

    deinit {
        if let observer = observer {
            hangTracker.removeObserver(id: observer)
        }
    }

    func processHitch(duration: TimeInterval, isOngoing: Bool) {
        hitchDurationCounter += duration

        // Get the stacktrace of the main thread
        let threads = threadInspector.getCurrentThreadsWithStackTrace()
        if let mainThread = threads.first(where: { $0.isMain == 1 }), let stacktrace = mainThread.stacktrace {
            stacktraces.append(stacktrace)
        }

        if isOngoing {
            return
        }

        // Hang is over, so notify an
        if hitchDurationCounter > options.appHangThreshold {
            SentrySDKLog.warning("App is hung for \(hitchDurationCounter) seconds")
            onHangDetected.send(HangData(duration: hitchDurationCounter, stacktraces: stacktraces))
        }

        // Reset the counter after submit
        hitchDurationCounter = 0
        stacktraces = []
    }
}
#endif
