import Foundation
#if compiler(>=6.4) && canImport(StateReporting)
import StateReporting
#endif
#if !SDK_V10
import SentrySwift
#else
import Sentry
#endif

final class MetricKitHangStressor {
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

    func start(workload: String, operation: () throws -> Int) {
        reportState(workload)
        defer { reportState(nil) }

        SentrySDK.logger.info(
            "MetricKit hang stressor started",
            attributes: ["stressor": "hang", "workload": workload]
        )

        // Run all four batches synchronously on the main thread for one continuous ~4 second hang.
        let startTime = ProcessInfo.processInfo.systemUptime
        do {
            var checksum = 0
            for _ in 0..<4 {
                checksum &+= try operation()
            }
            SentrySDK.logger.info(
                "MetricKit hang stressor completed",
                attributes: [
                    "stressor": "hang",
                    "workload": workload,
                    "duration_seconds": ProcessInfo.processInfo.systemUptime - startTime,
                    "checksum": checksum
                ]
            )
        } catch {
            SentrySDK.logger.error(
                "MetricKit hang stressor failed",
                attributes: ["stressor": "hang", "workload": workload, "error": error.localizedDescription]
            )
        }
    }
}
