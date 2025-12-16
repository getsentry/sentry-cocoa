import AppKit
import Sentry

class MetricsViewController: NSViewController {
    @IBAction func addCountAction(_ sender: Any) {
        // Counter metric - demonstrates all supported attribute types as variables and literals
        let actionType = "button_click"
        let windowActive = true
        let clickCount = 42
        let clickDuration = 0.123

        let actionTypes = ["button_click", "key_press", "menu_select"]
        let windowStates = [true, false, true]
        let clickCounts = [10, 20, 30]
        let clickDurations = [0.1, 0.2, 0.3]

        SentrySDK.metrics.count(
            key: "macos.app.action",
            value: 1,
            unit: "action",
            attributes: [
                // -- Variables --
                "action_type": actionType, // String
                "window_active": windowActive, // Boolean
                "click_count": clickCount, // Integer
                "click_duration": clickDuration, // Double

                "action_types": actionTypes, // String array
                "window_states": windowStates, // Boolean array
                "click_counts": clickCounts, // Integer array
                "click_durations": clickDurations, // Double array

                // -- Literals (showcases ExpressibleBy implementations) --
                "window": "main", // String
                "focused": false, // Boolean
                "retry_count": 3, // Integer
                "avg_duration": 0.15, // Double

                "windows": ["main", "secondary"], // String array
                "focus_states": [true, false], // Boolean array
                "retry_counts": [1, 2, 3], // Integer array
                "avg_durations": [0.1, 0.2] // Double array
            ]
        )
    }

    @IBAction func addDistributionAction(_ sender: Any) {
        // Distribution metric - demonstrates all supported attribute types as variables and literals
        let responseTime = Double.random(in: 10...100)
        let endpoint = "/api/data"
        let cached = false
        let statusCode = 200
        let responseSize = 1_024.5

        let endpoints = ["/api/data", "/api/users", "/api/orders"]
        let cacheStates = [true, false, true]
        let statusCodes = [200, 201, 404]
        let responseSizes = [512.0, 1_024.0, 2_048.0]

        SentrySDK.metrics.distribution(
            key: "macos.network.response_time",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                // -- Variables --
                "endpoint": endpoint, // String
                "cached": cached, // Boolean
                "status_code": statusCode, // Integer
                "response_size": responseSize, // Double

                "endpoints": endpoints, // String array
                "cache_states": cacheStates, // Boolean array
                "status_codes": statusCodes, // Integer array
                "response_sizes": responseSizes, // Double array

                // -- Literals (showcases ExpressibleBy implementations) --
                "protocol": "https", // String
                "compressed": true, // Boolean
                "retry_count": 0, // Integer
                "compression_ratio": 0.75, // Double

                "protocols": ["https", "http"], // String array
                "compressed_states": [true, false], // Boolean array
                "retry_counts": [0, 1, 2], // Integer array
                "compression_ratios": [0.7, 0.8] // Double array
            ]
        )
    }

    @IBAction func addGaugeAction(_ sender: Any) {
        // Gauge metric - demonstrates all supported attribute types as variables and literals
        let memoryUsage = Double.random(in: 512...2_048)
        let process = "main_app"
        let compressed = true
        let pressureLevel = 2
        let compressionRatio = 0.85

        let processes = ["main_app", "helper", "daemon"]
        let compressedStates = [true, false, true]
        let pressureLevels = [1, 2, 3]
        let compressionRatios = [0.8, 0.9, 0.7]

        SentrySDK.metrics.gauge(
            key: "macos.memory.usage",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                // -- Variables --
                "process": process, // String
                "compressed": compressed, // Boolean
                "pressure_level": pressureLevel, // Integer
                "compression_ratio": compressionRatio, // Double

                "processes": processes, // String array
                "compressed_states": compressedStates, // Boolean array
                "pressure_levels": pressureLevels, // Integer array
                "compression_ratios": compressionRatios, // Double array

                // -- Literals (showcases ExpressibleBy implementations) --
                "memory_type": "resident", // String
                "swapped": false, // Boolean
                "thread_count": 42, // Integer
                "utilization": 0.75, // Double

                "memory_types": ["resident", "virtual"], // String array
                "swapped_states": [false, true], // Boolean array
                "thread_counts": [10, 20, 30], // Integer array
                "utilizations": [0.7, 0.8, 0.9] // Double array
            ]
        )
    }
}
