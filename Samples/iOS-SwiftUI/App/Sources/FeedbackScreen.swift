import Sentry
import SentrySwiftUI
import SwiftUI

struct FeedbackScreen: View {
    @State private var isFeedbackWidgetVisible = true

    var body: some View {
        VStack(spacing: 16) {
            Button("Present with Host") {
                SentrySDK.feedback.presentForm()
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

            Text("This screen tests SentrySDK.feedback.presentForm() via .sentryFeedbackForm() and the feedback widget in a SwiftUI app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Feedback")
    }
}
