import SentrySwift

final class MetricKitHangStressor {
    func start(workload: String, operation: () throws -> Int) {
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
