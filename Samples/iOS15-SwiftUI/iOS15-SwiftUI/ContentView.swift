import Sentry
import SwiftUI

struct ContentView: View {
    
    private func captureError() {
        Task {
            await captureErrorAsync()
        }
    }
    
    func captureErrorAsync() async {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error)
    }
    
    var body: some View {
        VStack(alignment: HorizontalAlignment.center, spacing: 16) {
            Button(action: captureError) {
                Text("Capture Error")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
