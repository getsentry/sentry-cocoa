import Sentry
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("Show Feedback Form") {
                SentrySDK.feedback.showForm()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
