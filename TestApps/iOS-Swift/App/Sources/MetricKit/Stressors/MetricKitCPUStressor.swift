import SentrySwift

final class MetricKitCPUStressor {
    private static let duration: TimeInterval = 180

    private let queue = DispatchQueue(
        label: "io.sentry.sample.metrickit.cpu",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let lock = NSLock()
    private var running = false

    func start() {
        lock.lock()
        guard !running else {
            lock.unlock()
            SentrySDK.logger.warn(
                "MetricKit CPU stressor already running",
                attributes: ["stressor": "cpu"]
            )
            return
        }
        running = true
        lock.unlock()

        let workerCount = ProcessInfo.processInfo.activeProcessorCount
        let group = DispatchGroup()
        let endTime = Date().addingTimeInterval(Self.duration)

        SentrySDK.logger.info(
            "MetricKit CPU stressor started",
            attributes: [
                "stressor": "cpu",
                "duration_seconds": Self.duration,
                "worker_count": workerCount
            ]
        )

        for _ in 0..<workerCount {
            group.enter()
            queue.async {
                defer { group.leave() }
                self.consumeCPU(until: endTime)
            }
        }

        group.notify(queue: queue) {
            self.lock.lock()
            self.running = false
            self.lock.unlock()

            SentrySDK.logger.info(
                "MetricKit CPU stressor completed",
                attributes: [
                    "stressor": "cpu",
                    "duration_seconds": Self.duration,
                    "worker_count": workerCount
                ]
            )
        }
    }

    private func consumeCPU(until endTime: Date) {
        var result = 0.0

        while Date() < endTime {
            for value in 1...100_000 {
                let input = Double(value)
                result += sin(input) * cos(input)
            }

            if result.isInfinite {
                print(result)
            }
        }
    }
}
