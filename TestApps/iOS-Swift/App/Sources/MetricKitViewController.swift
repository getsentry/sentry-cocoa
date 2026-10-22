import Foundation
import SentrySwift
import UIKit
#if compiler(>=6.4) && canImport(StateReporting)
import StateReporting
#endif

final class MetricKitViewController: UIViewController {
    private let diskWriteStressor = MetricKitDiskWriteStressor()
    private let cpuStressor = MetricKitCPUStressor()
    private let hangStressor = MetricKitHangStressor()

    @IBAction func triggerCrashDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        SentrySDK.logger.fatal(
            "MetricKit crash stressor started",
            attributes: ["stressor": "crash"]
        )
        SentrySDK.crash()
    }

    @IBAction func triggerDiskWriteExceptionDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        diskWriteStressor.start()
    }

    @IBAction func triggerCPUExceptionDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        cpuStressor.start()
    }

    @IBAction func triggerHangDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        hangStressor.start()
    }

    @IBAction func triggerFatalHangDiagnostic(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Trigger Fatal Hang?",
            message: "This freezes the app indefinitely. Use a physical device without a debugger. Background the app and wait. If iOS does not terminate it, close it manually, then relaunch. MetricKit reports may be delayed or absent.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Freeze App", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.highlightButton(sender)
            self.hangStressor.startFatalHang()
        })
        present(alert, animated: true)
    }
}

private final class MetricKitCPUStressor {
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

private final class MetricKitDiskWriteStressor {
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

private final class MetricKitHangStressor {
    private static let duration: TimeInterval = 3

    private func reportState(_ label: String?) {
        #if compiler(>=6.4) && canImport(StateReporting)
        if #available(iOS 27.0, *) {
            StateReporter<Never, Never>.reporter(for: "io.sentry.sample.metrickit").reportTransition(to: label)
        }
        #endif
    }

    func startFatalHang() {
        reportState("fatal_hang")
        SentrySDK.logger.fatal(
            "MetricKit fatal hang stressor started",
            attributes: ["stressor": "fatal_hang", "workload": "main_thread_blocking"]
        )

        // Intentionally never return to the main run loop. Watchdog termination and MetricKit
        // delivery require manual device testing because their timing is controlled by the OS.
        while true {
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func start() {
        let endTime = Date().addingTimeInterval(Self.duration)
        guard let imageData = Bundle.main.url(forResource: "Tongariro", withExtension: "jpg")
            .flatMap({ try? Data(contentsOf: $0) }) else {
            SentrySDK.logger.error(
                "MetricKit hang stressor image could not be loaded",
                attributes: ["stressor": "hang"]
            )
            return
        }

        reportState("non_fatal_hang")
        defer { reportState(nil) }

        SentrySDK.logger.info(
            "MetricKit hang stressor started",
            attributes: [
                "stressor": "hang",
                "duration_seconds": Self.duration,
                "workload": "image_decoding"
            ]
        )

        while Date() < endTime {
            autoreleasepool {
                _ = UIImage(data: imageData)?.preparingForDisplay()
            }
        }

        SentrySDK.logger.info(
            "MetricKit hang stressor completed",
            attributes: [
                "stressor": "hang",
                "duration_seconds": Self.duration,
                "workload": "image_decoding"
            ]
        )
    }
}
