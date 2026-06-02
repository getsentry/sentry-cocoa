import Sentry
import SentrySwiftUI
import SwiftUI

struct FeedbackScreen: View {
    @State private var isFeedbackFormPresented = false
    @State private var isFeedbackWidgetVisible = true

    var body: some View {
        VStack(spacing: 16) {
            Button("Present Form (.sheet)") {
                isFeedbackFormPresented = true
            }
            .buttonStyle(.borderedProminent)

            Button("Present Form (Convenience API)") {
                SentrySDK.feedback.show()
            }
            .buttonStyle(.borderedProminent)

            Button(isFeedbackWidgetVisible ? "Hide Widget" : "Show Widget") {
                if isFeedbackWidgetVisible {
                    SentrySDK.feedback.hideWidget()
                } else {
                    SentrySDK.feedback.showWidget()
                }
                isFeedbackWidgetVisible.toggle()
            }
            .buttonStyle(.borderedProminent)

            Text("This screen demonstrates presenting SentrySDK.FeedbackFormView with a SwiftUI sheet, the convenience API, and the feedback widget in a SwiftUI app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Feedback")
        .sheet(isPresented: $isFeedbackFormPresented) {
            SentrySDK.FeedbackFormView()
        }
    }
}
