import SentrySwift
import SwiftUI

struct FeedbackScreen: View {
    @State private var isFeedbackModifierPresented = false
    @State private var isFeedbackFormViewPresented = false
#if !SDK_V10
    @State private var isFeedbackWidgetVisible = false
#endif // !SDK_V10

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
                SentrySDK.feedback.show { config in
                    config.tags = ["presentation": "swiftui-convenience-api"]
                }
            }
            .buttonStyle(.borderedProminent)

#if !SDK_V10
            Button(isFeedbackWidgetVisible ? "Hide Widget (Deprecated)" : "Show Widget (Deprecated)") {
                if isFeedbackWidgetVisible {
                    SentrySDK.feedback.hideWidget()
                } else {
                    SentrySDK.feedback.showWidget()
                }
                isFeedbackWidgetVisible.toggle()
            }
            .buttonStyle(.borderedProminent)
#endif // !SDK_V10

            Text("This screen demonstrates presenting feedback with the SwiftUI view modifier, the form view, the convenience API, and the deprecated feedback widget in a SwiftUI app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Feedback")
        .sentryFeedback(isPresented: $isFeedbackModifierPresented) { config in
            config.tags = ["presentation": "swiftui-modifier"]
        }
        .sheet(isPresented: $isFeedbackFormViewPresented) {
            SentrySDK.FeedbackFormView { config in
                config.configureForm = { form in
                    form.submitButtonLabel = "Send Feedback"
                }
                config.tags = ["presentation": "swiftui-form-view"]
            }
        }
    }
}
