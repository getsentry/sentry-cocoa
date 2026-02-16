import SentrySwift
import SwiftUI

private enum SampleError: Error {
    case sampleError
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("SentrySPM tvOS")
                .font(.headline)
            Button("Capture Error") {
                SentrySDK.capture(error: SampleError.sampleError)
            }
        }
        .sentryTrace("Content View")
    }
}
