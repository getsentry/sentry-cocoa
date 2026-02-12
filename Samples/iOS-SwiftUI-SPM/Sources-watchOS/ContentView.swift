import SentrySwift
import SwiftUI

private enum SampleError: Error {
    case sampleError
}

struct ContentView: View {
    var body: some View {
        List {
            Text("SentrySPM watchOS")
                .font(.headline)
            Button("Capture Error") {
                SentrySDK.capture(error: SampleError.sampleError)
            }
        }
        .sentryTrace("Content View")
    }
}
