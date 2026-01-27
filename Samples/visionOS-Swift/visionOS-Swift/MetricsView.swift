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
        let interactionType = "gesture"
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.string",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_type": interactionType,
                "device": "vision_pro"
            ]
        )

        let handTracking = true
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.boolean",
            value: 1,
            unit: "interaction",
            attributes: [
                "hand_tracking": handTracking,
                "eye_tracking": false
            ]
        )

        let sessionId = 98_765
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.integer",
            value: 1,
            unit: "interaction",
            attributes: [
                "session_id": sessionId,
                "retry_count": 0
            ]
        )

        let interactionAccuracy = 0.95
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.double",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_accuracy": interactionAccuracy,
                "avg_accuracy": 0.93
            ]
        )

        let interactionTypes = ["gesture", "pinch", "grab"]
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.string_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_types": interactionTypes,
                "devices": ["vision_pro", "hand"]
            ]
        )

        let handTrackingStates = [true, false, true]
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.boolean_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "hand_tracking_states": handTrackingStates,
                "eye_tracking_states": [true, false]
            ]
        )

        let sessionIds = [98_765, 98_766, 98_767]
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.integer_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "session_ids": sessionIds,
                "retry_counts": [0, 1, 2]
            ]
        )

        let interactionAccuracies = [0.9, 0.95, 0.98]
        SentrySDK.metrics.count(
            key: "visionos.app.interaction.double_array",
            value: 1,
            unit: "interaction",
            attributes: [
                "interaction_accuracies": interactionAccuracies,
                "avg_accuracies": [0.9, 0.95]
            ]
        )
    }

    /// Distribution metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordDistributionMetric() {
        let renderTime = Double.random(in: 8...16)

        let scene = "immersive_space"
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.string",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "scene": scene,
                "render_mode": "passthrough"
            ]
        )

        let foveated = true
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.boolean",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "foveated": foveated,
                "hdr_enabled": true
            ]
        )

        let frameCount = 90
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.integer",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "frame_count": frameCount,
                "buffer_count": 2
            ]
        )

        let fps = 90.0
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.double",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "fps": fps,
                "avg_fps": 89.5
            ]
        )

        let scenes = ["immersive_space", "shared_space", "full_space"]
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.string_array",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "scenes": scenes,
                "render_modes": ["passthrough", "occlusion"]
            ]
        )

        let foveatedStates = [true, false, true]
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.boolean_array",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "foveated_states": foveatedStates,
                "hdr_states": [true, false]
            ]
        )

        let frameCounts = [60, 90, 120]
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.integer_array",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "frame_counts": frameCounts,
                "buffer_counts": [1, 2, 3]
            ]
        )

        let fpsValues = [60.0, 90.0, 120.0]
        SentrySDK.metrics.distribution(
            key: "visionos.rendering.frame_time.double_array",
            value: renderTime,
            unit: "millisecond",
            attributes: [
                "fps_values": fpsValues,
                "avg_fps_values": [89.0, 90.0]
            ]
        )
    }

    /// Gauge metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordGaugeMetric() {
        let spatialAnchors = Double.random(in: 0...50)

        let spaceType = "full_space"
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.string",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "space_type": spaceType,
                "anchor_type": "plane"
            ]
        )

        let tracked = true
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.boolean",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "tracked": tracked,
                "stabilized": false
            ]
        )

        let maxAnchors = 100
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.integer",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "max_anchors": maxAnchors,
                "update_count": 42
            ]
        )

        let trackingAccuracy = 0.98
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.double",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "tracking_accuracy": trackingAccuracy,
                "stability": 0.97
            ]
        )

        let spaceTypes = ["full_space", "shared_space", "windowed"]
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.string_array",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "space_types": spaceTypes,
                "anchor_types": ["plane", "mesh"]
            ]
        )

        let trackedStates = [true, false, true]
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.boolean_array",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "tracked_states": trackedStates,
                "stabilized_states": [true, false]
            ]
        )

        let maxAnchorsList = [50, 100, 200]
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.integer_array",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "max_anchors_list": maxAnchorsList,
                "update_counts": [10, 20, 30]
            ]
        )

        let trackingAccuracies = [0.95, 0.98, 0.99]
        SentrySDK.metrics.gauge(
            key: "visionos.spatial.anchors.double_array",
            value: spatialAnchors,
            unit: "anchor",
            attributes: [
                "tracking_accuracies": trackingAccuracies,
                "stabilities": [0.95, 0.98]
            ]
        )
    }
}
// swiftlint:enable function_body_length
