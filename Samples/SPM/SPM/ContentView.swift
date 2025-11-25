import SentrySwift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Sentry SDK")
                .font(.title)
            VStack(spacing: 8) {
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Button("Show Feedback Form") {
                        SentrySDK.feedback.showForm()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    ContentView()
}
