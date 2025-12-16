import Sentry
import SwiftUI

struct MetricsView: View {
    var body: some View {
        VStack {
            Button(action: {
                // Counter metric - demonstrates all supported attribute types as variables and literals
                let actionType = "button_tap"
                let complicationVisible = true
                let workoutId = 42_001
                let tapAccuracy = 0.98

                let actionTypes = ["button_tap", "crown_rotate", "swipe"]
                let complicationStates = [true, false, true]
                let workoutIds = [42_001, 42_002, 42_003]
                let tapAccuracies = [0.95, 0.98, 0.99]

                SentrySDK.metrics.count(
                    key: "watchos.app.interaction",
                    value: 1,
                    unit: "interaction",
                    attributes: [
                        // -- Variables --
                        "action_type": actionType, // String
                        "complication_visible": complicationVisible, // Boolean
                        "workout_id": workoutId, // Integer
                        "tap_accuracy": tapAccuracy, // Double

                        "action_types": actionTypes, // String array
                        "complication_states": complicationStates, // Boolean array
                        "workout_ids": workoutIds, // Integer array
                        "tap_accuracies": tapAccuracies, // Double array

                        // -- Literals (showcases ExpressibleBy implementations) --
                        "screen": "main", // String
                        "always_on": false, // Boolean
                        "retry_count": 0, // Integer
                        "avg_accuracy": 0.97, // Double

                        "screens": ["main", "workout"], // String array
                        "always_on_states": [true, false], // Boolean array
                        "retry_counts": [0, 1, 2], // Integer array
                        "avg_accuracies": [0.95, 0.98] // Double array
                    ]
                )
            }) {
                Text("Record Counter Metric")
            }

            Button(action: {
                // Distribution metric - demonstrates all supported attribute types as variables and literals
                let launchTime = Double.random(in: 100...500)
                let workoutType = "running"
                let heartRateEnabled = true
                let sessionCount = 15
                let avgHeartRate = 145.5

                let workoutTypes = ["running", "cycling", "swimming"]
                let heartRateStates = [true, false, true]
                let sessionCounts = [10, 15, 20]
                let avgHeartRates = [140.0, 145.0, 150.0]

                SentrySDK.metrics.distribution(
                    key: "watchos.app.launch_time",
                    value: launchTime,
                    unit: "millisecond",
                    attributes: [
                        // -- Variables --
                        "workout_type": workoutType, // String
                        "heart_rate_enabled": heartRateEnabled, // Boolean
                        "session_count": sessionCount, // Integer
                        "avg_heart_rate": avgHeartRate, // Double

                        "workout_types": workoutTypes, // String array
                        "heart_rate_states": heartRateStates, // Boolean array
                        "session_counts": sessionCounts, // Integer array
                        "avg_heart_rates": avgHeartRates, // Double array

                        // -- Literals (showcases ExpressibleBy implementations) --
                        "complication_type": "circular", // String
                        "background_refresh": true, // Boolean
                        "complication_count": 3, // Integer
                        "battery_level": 0.85, // Double

                        "complication_types": ["circular", "modular"], // String array
                        "background_refresh_states": [true, false], // Boolean array
                        "complication_counts": [2, 3, 4], // Integer array
                        "battery_levels": [0.8, 0.9] // Double array
                    ]
                )
            }) {
                Text("Record Distribution Metric")
            }

            Button(action: {
                // Gauge metric - demonstrates all supported attribute types as variables and literals
                // Showcases Attributable protocol and ExpressibleBy implementations
                let activeWorkouts = Double.random(in: 0...3)
                let workoutCategory = "fitness"
                let gpsEnabled = true
                let maxWorkouts = 5
                let completionRate = 0.92

                let workoutCategories = ["fitness", "outdoor", "indoor"]
                let gpsStates = [true, false, true]
                let maxWorkoutsList = [3, 5, 10]
                let completionRates = [0.9, 0.92, 0.95]

                SentrySDK.metrics.gauge(
                    key: "watchos.workout.active",
                    value: activeWorkouts,
                    unit: "workout",
                    attributes: [
                        // -- Variables --
                        "workout_category": workoutCategory, // String
                        "gps_enabled": gpsEnabled, // Boolean
                        "max_workouts": maxWorkouts, // Integer
                        "completion_rate": completionRate, // Double

                        "workout_categories": workoutCategories, // String array
                        "gps_states": gpsStates, // Boolean array
                        "max_workouts_list": maxWorkoutsList, // Integer array
                        "completion_rates": completionRates, // Double array

                        // -- Literals (showcases ExpressibleBy implementations) --
                        "device_model": "apple_watch", // String
                        "water_resistant": true, // Boolean
                        "heart_rate_zones": 5, // Integer
                        "battery_health": 0.88, // Double

                        "device_models": ["apple_watch", "ultra"], // String array
                        "water_resistant_states": [true, false], // Boolean array
                        "heart_rate_zones_list": [3, 5, 7], // Integer array
                        "battery_health_levels": [0.85, 0.90] // Double array
                    ]
                )
            }) {
                Text("Record Gauge Metric")
            }
        }
    }
}
