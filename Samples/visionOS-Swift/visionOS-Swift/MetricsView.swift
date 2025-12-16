import Sentry
import SwiftUI

struct MetricsView: View {
    var body: some View {
        VStack {
            Button(action: {
                // Counter metric - demonstrates all supported attribute types as variables and literals
                let interactionType = "gesture"
                let handTracking = true
                let sessionId = 98_765
                let interactionAccuracy = 0.95

                let interactionTypes = ["gesture", "pinch", "grab"]
                let handTrackingStates = [true, false, true]
                let sessionIds = [98_765, 98_766, 98_767]
                let interactionAccuracies = [0.9, 0.95, 0.98]

                SentrySDK.metrics.count(
                    key: "visionos.app.interaction",
                    value: 1,
                    unit: "interaction",
                    attributes: [
                        // -- Variables --
                        "interaction_type": interactionType, // String
                        "hand_tracking": handTracking, // Boolean
                        "session_id": sessionId, // Integer
                        "interaction_accuracy": interactionAccuracy, // Double

                        "interaction_types": interactionTypes, // String array
                        "hand_tracking_states": handTrackingStates, // Boolean array
                        "session_ids": sessionIds, // Integer array
                        "interaction_accuracies": interactionAccuracies, // Double array

                        // -- Literals (showcases ExpressibleBy implementations) --
                        "device": "vision_pro", // String
                        "eye_tracking": false, // Boolean
                        "retry_count": 0, // Integer
                        "avg_accuracy": 0.93, // Double

                        "devices": ["vision_pro", "hand"], // String array
                        "eye_tracking_states": [true, false], // Boolean array
                        "retry_counts": [0, 1, 2], // Integer array
                        "avg_accuracies": [0.9, 0.95] // Double array
                    ]
                )
            }) {
                Text("Record Counter Metric")
            }

            Button(action: {
                // Distribution metric - demonstrates all supported attribute types as variables and literals
                let renderTime = Double.random(in: 8...16)
                let scene = "immersive_space"
                let foveated = true
                let frameCount = 90
                let fps = 90.0

                let scenes = ["immersive_space", "shared_space", "full_space"]
                let foveatedStates = [true, false, true]
                let frameCounts = [60, 90, 120]
                let fpsValues = [60.0, 90.0, 120.0]

                SentrySDK.metrics.distribution(
                    key: "visionos.rendering.frame_time",
                    value: renderTime,
                    unit: "millisecond",
                    attributes: [
                        // -- Variables --
                        "scene": scene, // String
                        "foveated": foveated, // Boolean
                        "frame_count": frameCount, // Integer
                        "fps": fps, // Double

                        "scenes": scenes, // String array
                        "foveated_states": foveatedStates, // Boolean array
                        "frame_counts": frameCounts, // Integer array
                        "fps_values": fpsValues, // Double array

                        // -- Literals (showcases ExpressibleBy implementations) --
                        "render_mode": "passthrough", // String
                        "hdr_enabled": true, // Boolean
                        "buffer_count": 2, // Integer
                        "avg_fps": 89.5, // Double

                        "render_modes": ["passthrough", "occlusion"], // String array
                        "hdr_states": [true, false], // Boolean array
                        "buffer_counts": [1, 2, 3], // Integer array
                        "avg_fps_values": [89.0, 90.0] // Double array
                    ]
                )
            }) {
                Text("Record Distribution Metric")
            }

            Button(action: {
                // Gauge metric - demonstrates all supported attribute types as variables and literals
                let spatialAnchors = Double.random(in: 0...50)
                let spaceType = "full_space"
                let tracked = true
                let maxAnchors = 100
                let trackingAccuracy = 0.98

                let spaceTypes = ["full_space", "shared_space", "windowed"]
                let trackedStates = [true, false, true]
                let maxAnchorsList = [50, 100, 200]
                let trackingAccuracies = [0.95, 0.98, 0.99]

                SentrySDK.metrics.gauge(
                    key: "visionos.spatial.anchors",
                    value: spatialAnchors,
                    unit: "anchor",
                    attributes: [
                        // -- Variables --
                        "space_type": spaceType, // String
                        "tracked": tracked, // Boolean
                        "max_anchors": maxAnchors, // Integer
                        "tracking_accuracy": trackingAccuracy, // Double

                        "space_types": spaceTypes, // String array
                        "tracked_states": trackedStates, // Boolean array
                        "max_anchors_list": maxAnchorsList, // Integer array
                        "tracking_accuracies": trackingAccuracies, // Double array

                        // -- Literals (showcases ExpressibleBy implementations) --
                        "anchor_type": "plane", // String
                        "stabilized": false, // Boolean
                        "update_count": 42, // Integer
                        "stability": 0.97, // Double

                        "anchor_types": ["plane", "mesh"], // String array
                        "stabilized_states": [true, false], // Boolean array
                        "update_counts": [10, 20, 30], // Integer array
                        "stabilities": [0.95, 0.98] // Double array
                    ]
                )
            }) {
                Text("Record Gauge Metric")
            }
        }
    }
}
