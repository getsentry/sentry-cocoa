// swiftlint:disable function_body_length
import Sentry
import SwiftUI

struct MetricsView: View {
    var body: some View {
        VStack {
            Button(action: recordCounterMetric) {
                Text("Record Counter Metric")
            }
            Button(action: recordDistributionMetric) {
                Text("Record Distribution Metric")
            }
            Button(action: recordGaugeMetric) {
                Text("Record Gauge Metric")
            }
        }
    }

    /// Counter metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordCounterMetric() {
        let interactionType = "button_press"
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.string",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_type": interactionType,
                "device": "apple_tv"
            ]
        )

        let focused = true
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.boolean",
            value: 1,
            unit: "interaction",
            attributes: [
                "focused": focused,
                "active": false
            ]
        )

        let sessionId = 12_345
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.integer",
            value: 1,
            unit: "interaction",
            attributes: [
                "session_id": sessionId,
                "retry_count": 0
            ]
        )

        let interactionDuration = 0.5
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.double",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_duration": interactionDuration,
                "avg_duration": 0.4
            ]
        )

        let interactionTypes = ["button_press", "swipe", "tap"]
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.string_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_types": interactionTypes,
                "devices": ["apple_tv", "remote"]
            ]
        )

        let focusStates = [true, false, true]
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.boolean_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "focus_states": focusStates,
                "active_states": [true, false]
            ]
        )

        let sessionIds = [12_345, 12_346, 12_347]
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.integer_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "session_ids": sessionIds,
                "retry_counts": [0, 1, 2]
            ]
        )

        let interactionDurations = [0.3, 0.5, 0.7]
        SentrySDK.metrics.count(
            key: "tvos.app.interaction.double_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_durations": interactionDurations,
                "avg_durations": [0.3, 0.4]
            ]
        )
    }

    /// Distribution metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordDistributionMetric() {
        let frameTime = Double.random(in: 16...33)
        let scene = "main_menu"
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.string",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "scene": scene,
                "resolution": "4k"
            ]
        )

        let vsyncEnabled = true
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.boolean",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "vsync_enabled": vsyncEnabled,
                "hdr_enabled": false
            ]
        )

        let frameCount = 60
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.integer",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "frame_count": frameCount,
                "buffer_count": 3
            ]
        )

        let fps = 60.0
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.double",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "fps": fps,
                "avg_fps": 59.5
            ]
        )

        let scenes = ["main_menu", "settings", "player"]
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.string_array",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "scenes": scenes,
                "resolutions": ["4k", "1080p"]
            ]
        )

        let vsyncStates = [true, false, true]
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.boolean_array",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "vsync_states": vsyncStates,
                "hdr_states": [true, false]
            ]
        )

        let frameCounts = [30, 60, 120]
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.integer_array",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "frame_counts": frameCounts,
                "buffer_counts": [2, 3, 4]
            ]
        )

        let fpsValues = [30.0, 60.0, 120.0]
        SentrySDK.metrics.distribution(
            key: "tvos.rendering.frame_time.double_array",
            value: frameTime,
            unit: "millisecond",
            attributes: [
                "fps_values": fpsValues,
                "avg_fps_values": [59.0, 60.0]
            ]
        )
    }

    /// Gauge metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordGaugeMetric() {
        let activeConnections = Double.random(in: 0...10)
        let networkType = "wifi"
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.string",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "network_type": networkType,
                "protocol": "tcp"
            ]
        )

        let secure = true
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.boolean",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "secure": secure,
                "compressed": false
            ]
        )

        let port = 443
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.integer",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "port": port,
                "max_connections": 100
            ]
        )

        let maxBandwidth = 100.0
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.double",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "max_bandwidth": maxBandwidth,
                "utilization": 0.75
            ]
        )

        let networkTypes = ["wifi", "ethernet", "cellular"]
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.string_array",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "network_types": networkTypes,
                "protocols": ["tcp", "udp"]
            ]
        )

        let secureStates = [true, false, true]
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.boolean_array",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "secure_states": secureStates,
                "compressed_states": [true, false]
            ]
        )

        let ports = [80, 443, 8_080]
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.integer_array",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "ports": ports,
                "max_connections_list": [50, 100, 200]
            ]
        )

        let maxBandwidths = [50.0, 100.0, 200.0]
        SentrySDK.metrics.gauge(
            key: "tvos.network.connections.double_array",
            value: activeConnections,
            unit: "connection",
            attributes: [
                "max_bandwidths": maxBandwidths,
                "utilizations": [0.7, 0.8]
            ]
        )
    }
}
// swiftlint:enable function_body_length
