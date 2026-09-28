import ActivityKit
import SwiftUI

struct LiveActivityView: View {
    @StateObject private var viewModel = LiveActivityViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Live Activity Test")
                .font(.title)
            
            // Debug info
            VStack(alignment: .leading, spacing: 8) {
                Text("Debug Info:")
                    .font(.headline)
                Text("Activities Enabled: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "Yes" : "No")")
                    .font(.caption)
                Text("Existing Activities: \(Activity<LiveActivityAttributes>.activities.count)")
                    .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Simulator note
            VStack(alignment: .leading, spacing: 4) {
                Text("ℹ️ Simulator Note:")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Live Activities show on lock screen in simulator. Dynamic Island requires a physical iPhone 14 Pro or later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            if let activityViewState = viewModel.activityViewState {
                VStack(spacing: 10) {
                    Text("✅ Live Activity is running")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text(activityViewState.pushToken ?? "No token available")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Lock the simulator to see it on the lock screen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("End Activity") {
                        Task {
                            await viewModel.endLiveActivity()
                        }
                    }
                    .buttonStyle(.bordered)
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
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
