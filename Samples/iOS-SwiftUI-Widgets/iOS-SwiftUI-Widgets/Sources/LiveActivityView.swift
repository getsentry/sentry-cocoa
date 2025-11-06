import ActivityKit
@_spi(Private) @testable import Sentry
import SwiftUI
import UserNotifications

struct LiveActivityView: View {
    @StateObject private var viewModel = LiveActivityViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Live Activity Test")
                .font(.title)
            
            if viewModel.isActivityActive {
                VStack(spacing: 10) {
                    Text("Live Activity is running")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("It will end automatically in 10 seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            } else {
                Button("Start Live Activity") {
                    viewModel.startLiveActivity()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            viewModel.setupSentrySDK()
        }
    }
}

@MainActor
final class LiveActivityViewModel: ObservableObject {
    @Published var isActivityActive = false
    @Published var errorMessage: String?
    
    private var currentActivity: Activity<LiveActivityAttributes>?
    
    func setupSentrySDK() {
        guard !SentrySDK.isEnabled else {
            return
        }
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.enableAppHangTracking = true
        }
    }
    
    func startLiveActivity() {
        Task {
            // Request notification permissions if needed
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            
            if settings.authorizationStatus == .notDetermined {
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .providesAppNotificationSettings])
                    if !granted {
                        self.errorMessage = "Notification permissions are required for Live Activities."
                        return
                    }
                } catch {
                    self.errorMessage = "Failed to request notification permissions: \(error.localizedDescription)"
                    return
                }
            } else if settings.authorizationStatus == .denied {
                self.errorMessage = "Notification permissions are denied. Please enable notifications in Settings."
                return
            }
            
            // Check if Live Activities are enabled
            let authInfo = ActivityAuthorizationInfo()
            guard authInfo.areActivitiesEnabled else {
                self.errorMessage = "Live Activities are not enabled. Please enable them in Settings."
                return
            }
            
            do {
                // Check ANR tracking status
                let anrInstalled = SentrySDK.isEnabled &&
                    SentrySDKInternal.trimmedInstalledIntegrationNames()
                        .contains("ANRTracking")
                
                let anrStatus = anrInstalled ? "Enabled" : "Disabled"
                
                let attributes = LiveActivityAttributes(id: UUID().uuidString)
                let initialState = LiveActivityAttributes.ContentState(
                    anrTrackingStatus: anrStatus,
                    timestamp: Date()
                )
                
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: nil),
                    pushType: .token
                )
                
                self.currentActivity = activity
                self.isActivityActive = true
                self.errorMessage = nil
                
                // Auto-end after 10 seconds
                Task {
                    try? await Task.sleep(for: .seconds(10))
                    await self.endLiveActivity()
                }
            } catch {
                self.errorMessage = "Failed to start Live Activity: \(error.localizedDescription)"
            }
        }
    }
    
    func endLiveActivity() async {
        guard let activity = currentActivity else {
            return
        }
        
        // Check ANR tracking status again for final state
        let anrInstalled = SentrySDK.isEnabled &&
            SentrySDKInternal.trimmedInstalledIntegrationNames()
                .contains("ANRTracking")
        
        let anrStatus = anrInstalled ? "Enabled" : "Disabled"
        
        let finalState = LiveActivityAttributes.ContentState(
            anrTrackingStatus: anrStatus,
            timestamp: Date()
        )
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        await MainActor.run {
            self.currentActivity = nil
            self.isActivityActive = false
        }
    }
}
