import ActivityKit
import os.log
import SwiftUI

@MainActor
final class LiveActivityViewModel: ObservableObject {
    struct ActivityViewState: Sendable {
        var activityState: ActivityState
        var contentState: LiveActivityAttributes.ContentState
        var pushToken: String?
    }

    @Published var activityViewState: ActivityViewState?
    @Published var errorMessage: String?
    
    private var currentActivity: Activity<LiveActivityAttributes>?

    private let logger = Logger(subsystem: "io.sentry.sentry-cocoa.samples.iOS-SwiftUI-Widgets", category: "LiveActivity")

    func startLiveActivity() {
        logger.info("Starting Live Activity...")
        
        let authInfo = ActivityAuthorizationInfo()
        logger.info("Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            errorMessage = "Live Activities are not enabled. Please enable them in Settings."
            logger.error("Live Activities are not enabled")
            return
        }
        
        // Check for existing activities
        let existingActivities = Activity<LiveActivityAttributes>.activities
        logger.info("Existing activities count: \(existingActivities.count)")
        
        do {
            let attributes = LiveActivityAttributes(
                id: ""
            )
            let initialState = LiveActivityAttributes.ContentState(
                anrTrackingStatus: "Enabled",
                timestamp: Date()
            )
            
            logger.info("Requesting activity with attributes name: \(attributes.id)")

            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            logger.info("Activity created successfully! ID: \(activity.id), State: \(String(describing: activity.activityState))")
            logger.info("Activity content state: emoji=\(initialState.anrTrackingStatus)")
            logger.info("Activity pushToken initially: \(activity.pushToken?.hexadecimalString ?? "nil")")
            
            currentActivity = activity
            self.activityViewState = .init(
                activityState: activity.activityState,
                contentState: activity.content.state,
                pushToken: activity.pushToken?.hexadecimalString
            )
            errorMessage = nil

            logger.info("Starting to observe activity updates")
            observeActivity(activity: activity)
            
            // Log all current activities for debugging
            let allActivities = Activity<LiveActivityAttributes>.activities
            logger.info("Total activities after creation: \(allActivities.count)")
            for (index, act) in allActivities.enumerated() {
                logger.info("Activity \(index): ID=\(act.id), State=\(String(describing: act.activityState))")
            }
        } catch {
            let errorDescription = error.localizedDescription
            logger.error("Failed to start Live Activity: \(errorDescription)")
            let nsError = error as NSError
            logger.error("NSError domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)")
            errorMessage = "Failed to start Live Activity: \(errorDescription)"
        }
    }

    func observeActivity(activity: Activity<LiveActivityAttributes>) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    for await activityState in activity.activityStateUpdates {
                        self.logger.info("Activity state changed: \(String(describing: activityState))")
                        if activityState == .dismissed {
                            self.logger.info("Activity was dismissed, cleaning up")
                            self.cleanUpDismissedActivity()
                        } else {
                            self.activityViewState?.activityState = activityState
                            self.logger.info("Updated activityViewState.activityState to: \(String(describing: activityState))")
                        }
                    }
                }

                group.addTask { @MainActor in
                    for await contentState in activity.contentUpdates {
                        self.logger.info("Content state updated: emoji=\(contentState.state.anrTrackingStatus)")
                        self.activityViewState?.contentState = contentState.state
                    }
                }

                group.addTask { @MainActor in
                    for await pushToken in activity.pushTokenUpdates {
                        let pushTokenString = pushToken.hexadecimalString
                        let frequentUpdateEnabled = ActivityAuthorizationInfo().frequentPushesEnabled

                        self.logger.info("Push token received: \(pushTokenString)")
                        self.logger.info("Frequent updates enabled: \(frequentUpdateEnabled)")
                        
                        // Update the view state with the push token
                        self.activityViewState?.pushToken = pushTokenString
                    }
                }
            }
        }
    }

    func cleanUpDismissedActivity() {
        self.currentActivity = nil
        self.activityViewState = nil
    }

    func endLiveActivity() async {
        guard let activity = currentActivity else {
            logger.warning("No current activity to end")
            return
        }
        
        logger.info("Ending activity: \(activity.id)")
        
        let finalState = LiveActivityAttributes.ContentState(
            anrTrackingStatus: "Disabled",
            timestamp: Date()
        )
        
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        cleanUpDismissedActivity()

        logger.info("Activity ended")
    }
}

private extension Data {
    var hexadecimalString: String {
        self.reduce("") {
            $0 + String(format: "%02x", $1)
        }
    }
}
