import SentrySwift

final class MetricKitDiskWriteStressor {
    private static let payloadSize = 16 * 1_024 * 1_024
    private static let targetBytesWritten = 2 * 1_024 * 1_024 * 1_024

    private let queue = DispatchQueue(label: "io.sentry.sample.metrickit.disk-write")
    private let payload = Data(repeating: 0xA5, count: MetricKitDiskWriteStressor.payloadSize)
    private let fileURL: URL
    private let lock = NSLock()
    private var running = false

    init() {
        // swiftlint:disable:next force_unwrapping
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        fileURL = cachesDirectory
            .appendingPathComponent("MetricKitDiskWriteStressor", isDirectory: true)
            .appendingPathComponent("payload.bin")
    }

    func start() {
        lock.lock()
        guard !running else {
            lock.unlock()
            SentrySDK.logger.warn(
                "MetricKit disk-write stressor already running",
                attributes: ["stressor": "disk_write"]
            )
            return
        }
        running = true
        lock.unlock()

        SentrySDK.logger.info(
            "MetricKit disk-write stressor started",
            attributes: [
                "stressor": "disk_write",
                "payload_size_bytes": Self.payloadSize,
                "target_bytes_written": Self.targetBytesWritten
            ]
        )

        queue.async { [self] in
            writePayload()
        }
    }

    private func writePayload() {
        defer {
            lock.lock()
            running = false
            lock.unlock()
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var bytesWritten = 0
            while bytesWritten < Self.targetBytesWritten {
                try payload.write(to: fileURL, options: .atomic)
                bytesWritten += payload.count
            }

            SentrySDK.logger.info(
                "MetricKit disk-write stressor completed",
                attributes: [
                    "stressor": "disk_write",
                    "bytes_written": bytesWritten
                ]
            )
        } catch {
            SentrySDK.logger.error(
                "MetricKit disk-write stressor failed",
                attributes: [
                    "stressor": "disk_write",
                    "error": error.localizedDescription
                ]
            )
            SentrySDK.capture(error: error)
        }
    }
}
