import SentrySwift
import SwiftUI

private enum SampleError: Error {
    case sampleError
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("SentrySPM macOS")
                .font(.headline)
            Button("Capture Error") {
                SentrySDK.capture(error: SampleError.sampleError)
            }
        }
        .padding()
        .sentryTrace("Content View")
    }
}
