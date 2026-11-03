// swiftlint:disable function_body_length type_body_length
import SentrySwift
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
        let actionType = "button_tap"
        SentrySDK.metrics.count(
            "watchos.app.interaction.string",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "action_type": actionType,
                    "screen": "main"
                ]
            )
        )

        let complicationVisible = true
        SentrySDK.metrics.count(
            "watchos.app.interaction.boolean",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "complication_visible": complicationVisible,
                    "always_on": false
                ]
            )
        )

        let workoutId = 42_001
        SentrySDK.metrics.count(
            "watchos.app.interaction.integer",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "workout_id": workoutId,
                    "retry_count": 0
                ]
            )
        )

        let tapAccuracy = 0.98
        SentrySDK.metrics.count(
            "watchos.app.interaction.double",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "tap_accuracy": tapAccuracy,
                    "avg_accuracy": 0.97
                ]
            )
        )

        let actionTypes = ["button_tap", "crown_rotate", "swipe"]
        SentrySDK.metrics.count(
            "watchos.app.interaction.string_array",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "action_types": actionTypes,
                    "screens": ["main", "workout"]
                ]
            )
        )

        let complicationStates = [true, false, true]
        SentrySDK.metrics.count(
            "watchos.app.interaction.boolean_array",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "complication_states": complicationStates,
                    "always_on_states": [true, false]
                ]
            )
        )

        let workoutIds = [42_001, 42_002, 42_003]
        SentrySDK.metrics.count(
            "watchos.app.interaction.integer_array",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "workout_ids": workoutIds,
                    "retry_counts": [0, 1, 2]
                ]
            )
        )

        let tapAccuracies = [0.95, 0.98, 0.99]
        SentrySDK.metrics.count(
            "watchos.app.interaction.double_array",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "tap_accuracies": tapAccuracies,
                    "avg_accuracies": [0.95, 0.98]
                ]
            )
        )
    }

    /// Distribution metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordDistributionMetric() {
        let launchTime = Double.random(in: 100...500)
        let workoutType = "running"
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.string",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "workout_type": workoutType,
                    "complication_type": "circular"
                ]
            )
        )

        let heartRateEnabled = true
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.boolean",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "heart_rate_enabled": heartRateEnabled,
                    "background_refresh": true
                ]
            )
        )

        let sessionCount = 15
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.integer",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "session_count": sessionCount,
                    "complication_count": 3
                ]
            )
        )

        let avgHeartRate = 145.5
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.double",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "avg_heart_rate": avgHeartRate,
                    "battery_level": 0.85
                ]
            )
        )

        let workoutTypes = ["running", "cycling", "swimming"]
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.string_array",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "workout_types": workoutTypes,
                    "complication_types": ["circular", "modular"]
                ]
            )
        )

        let heartRateStates = [true, false, true]
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.boolean_array",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "heart_rate_states": heartRateStates,
                    "background_refresh_states": [true, false]
                ]
            )
        )

        let sessionCounts = [10, 15, 20]
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.integer_array",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "session_counts": sessionCounts,
                    "complication_counts": [2, 3, 4]
                ]
            )
        )

        let avgHeartRates = [140.0, 145.0, 150.0]
        SentrySDK.metrics.distribution(
            "watchos.app.launch_time.double_array",
            value: launchTime,
            options: SentryMetricOptions(
                unit: "millisecond",
                attributes: [
                    "avg_heart_rates": avgHeartRates,
                    "battery_levels": [0.8, 0.9]
                ]
            )
        )
    }

    /// Gauge metric - demonstrates all supported attribute types as variables and literals
    fileprivate func recordGaugeMetric() {
        let activeWorkouts = Double.random(in: 0...3)
        let workoutCategory = "fitness"
        SentrySDK.metrics.gauge(
            "watchos.workout.active.string",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "workout_category": workoutCategory,
                    "device_model": "apple_watch"
                ]
            )
        )

        let gpsEnabled = true
        SentrySDK.metrics.gauge(
            "watchos.workout.active.boolean",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "gps_enabled": gpsEnabled,
                    "water_resistant": true
                ]
            )
        )

        let maxWorkouts = 5
        SentrySDK.metrics.gauge(
            "watchos.workout.active.integer",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "max_workouts": maxWorkouts,
                    "heart_rate_zones": 5
                ]
            )
        )

        let completionRate = 0.92
        SentrySDK.metrics.gauge(
            "watchos.workout.active.double",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "completion_rate": completionRate,
                    "battery_health": 0.88
                ]
            )
        )

        let workoutCategories = ["fitness", "outdoor", "indoor"]
        SentrySDK.metrics.gauge(
            "watchos.workout.active.string_array",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "workout_categories": workoutCategories,
                    "device_models": ["apple_watch", "ultra"]
                ]
            )
        )

        let gpsStates = [true, false, true]
        SentrySDK.metrics.gauge(
            "watchos.workout.active.boolean_array",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "gps_states": gpsStates,
                    "water_resistant_states": [true, false]
                ]
            )
        )

        let maxWorkoutsList = [3, 5, 10]
        SentrySDK.metrics.gauge(
            "watchos.workout.active.integer_array",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "max_workouts_list": maxWorkoutsList,
                    "heart_rate_zones_list": [3, 5, 7]
                ]
            )
        )

        let completionRates = [0.9, 0.92, 0.95]
        SentrySDK.metrics.gauge(
            "watchos.workout.active.double_array",
            value: activeWorkouts,
            options: SentryMetricOptions(
                unit: "workout",
                attributes: [
                    "completion_rates": completionRates,
                    "battery_health_levels": [0.85, 0.90]
                ]
            )
        )
    }
}
// swiftlint:enable function_body_length type_body_length
