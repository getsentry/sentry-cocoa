// swiftlint:disable function_body_length
import AppKit
import Sentry

class MetricsViewController: NSViewController {
    /// Counter metric - demonstrates all supported attribute types as variables and literals
    @IBAction func addCountAction(_ sender: Any) {
        let actionType = "button_click"
        SentrySDK.metrics.count(
            key: "macos.app.action.string",
            value: 1,
            attributes: [
                "action_type": actionType,
                "window": "main"
            ]
        )

        let windowActive = true
        SentrySDK.metrics.count(
            key: "macos.app.action.boolean",
            value: 1,
            attributes: [
                "window_active": windowActive,
                "focused": false
            ]
        )

        let clickCount = 42
        SentrySDK.metrics.count(
            key: "macos.app.action.integer",
            value: 1,
            attributes: [
                "click_count": clickCount,
                "retry_count": 3
            ]
        )

        let clickDuration = 0.123
        SentrySDK.metrics.count(
            key: "macos.app.action.double",
            value: 1,
            attributes: [
                "click_duration": clickDuration,
                "avg_duration": 0.15
            ]
        )

        let actionTypes = ["button_click", "key_press", "menu_select"]
        SentrySDK.metrics.count(
            key: "macos.app.action.string_array",
            value: 1,
            attributes: [
                "action_types": actionTypes,
                "windows": ["main", "secondary"]
            ]
        )

        let windowStates = [true, false, true]
        SentrySDK.metrics.count(
            key: "macos.app.action.boolean_array",
            value: 1,
            attributes: [
                "window_states": windowStates,
                "focus_states": [true, false]
            ]
        )

        let clickCounts = [10, 20, 30]
        SentrySDK.metrics.count(
            key: "macos.app.action.integer_array",
            value: 1,
            attributes: [
                "click_counts": clickCounts,
                "retry_counts": [1, 2, 3]
            ]
        )

        let clickDurations = [0.1, 0.2, 0.3]
        SentrySDK.metrics.count(
            key: "macos.app.action.double_array",
            value: 1,
            attributes: [
                "click_durations": clickDurations,
                "avg_durations": [0.1, 0.2]
            ]
        )
    }

    /// Distribution metric - demonstrates all supported attribute types as variables and literals
    @IBAction func addDistributionAction(_ sender: Any) {
        let responseTime = Double.random(in: 10...100)
        
        let endpoint = "/api/data"
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.string",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "endpoint": endpoint,
                "protocol": "https"
            ]
        )

        let cached = false
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.boolean",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "cached": cached,
                "compressed": true
            ]
        )

        let statusCode = 200
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.integer",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "status_code": statusCode,
                "retry_count": 0
            ]
        )

        let responseSize = 1_024.5
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.double",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "response_size": responseSize,
                "compression_ratio": 0.75
            ]
        )

        let endpoints = ["/api/data", "/api/users", "/api/orders"]
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.string_array",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "endpoints": endpoints,
                "protocols": ["https", "http"]
            ]
        )

        let cacheStates = [true, false, true]
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.boolean_array",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "cache_states": cacheStates,
                "compressed_states": [true, false]
            ]
        )

        let statusCodes = [200, 201, 404]
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.integer_array",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "status_codes": statusCodes,
                "retry_counts": [0, 1, 2]
            ]
        )

        let responseSizes = [512.0, 1_024.0, 2_048.0]
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time.double_array",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                "response_sizes": responseSizes,
                "compression_ratios": [0.7, 0.8]
            ]
        )
    }

    /// Gauge metric - demonstrates all supported attribute types as variables and literals
    @IBAction func addGaugeAction(_ sender: Any) {
        let memoryUsage = Double.random(in: 512...2_048)
        
        let process = "main_app"
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.string",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "process": process,
                "memory_type": "resident"
            ]
        )

        let compressed = true
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.boolean",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "compressed": compressed,
                "swapped": false
            ]
        )

        let pressureLevel = 2
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.integer",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "pressure_level": pressureLevel,
                "thread_count": 42
            ]
        )

        let compressionRatio = 0.85
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.double",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "compression_ratio": compressionRatio,
                "utilization": 0.75
            ]
        )

        let processes = ["main_app", "helper", "daemon"]
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.string_array",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "processes": processes,
                "memory_types": ["resident", "virtual"]
            ]
        )

        let compressedStates = [true, false, true]
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.boolean_array",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "compressed_states": compressedStates,
                "swapped_states": [false, true]
            ]
        )

        let pressureLevels = [1, 2, 3]
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.integer_array",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "pressure_levels": pressureLevels,
                "thread_counts": [10, 20, 30]
            ]
        )

        let compressionRatios = [0.8, 0.9, 0.7]
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage.double_array",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                "compression_ratios": compressionRatios,
                "utilizations": [0.7, 0.8, 0.9]
            ]
        )
    }
}
// swiftlint:enable function_body_length
