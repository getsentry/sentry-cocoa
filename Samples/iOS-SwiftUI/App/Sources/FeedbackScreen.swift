import Sentry
import SentrySwiftUI
import SwiftUI

struct FeedbackScreen: View {
    @State private var isFeedbackModifierPresented = false
    @State private var isFeedbackFormViewPresented = false
    @State private var isFeedbackWidgetVisible = false

    var body: some View {
        VStack(spacing: 16) {
            Button("Present Form (View Modifier)") {
                isFeedbackModifierPresented = true
            }
            .buttonStyle(.borderedProminent)

            Button("Present Form (Form View)") {
                isFeedbackFormViewPresented = true
            }
            .buttonStyle(.borderedProminent)

            Button("Present Form (Convenience API)") {
                SentrySDK.feedback.show()
            }
            .buttonStyle(.borderedProminent)

            Button(isFeedbackWidgetVisible ? "Hide Widget (Deprecated)" : "Show Widget (Deprecated)") {
                if isFeedbackWidgetVisible {
                    SentrySDK.feedback.hideWidget()
                } else {
                    SentrySDK.feedback.showWidget()
                }
                isFeedbackWidgetVisible.toggle()
            }
            .buttonStyle(.borderedProminent)

            Text("This screen demonstrates presenting feedback with the SwiftUI view modifier, the form view, the convenience API, and the deprecated feedback widget in a SwiftUI app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Feedback")
        .sentryFeedback(isPresented: $isFeedbackModifierPresented)
        .sheet(isPresented: $isFeedbackFormViewPresented) {
            SentrySDK.FeedbackFormView()
        }
    }
}
