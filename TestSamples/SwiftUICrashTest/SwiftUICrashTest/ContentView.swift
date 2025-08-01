import Sentry
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            let userDefaultsKey = "crash-on-launch"
            Text("Crash flag value: \(UserDefaults.standard.bool(forKey: userDefaultsKey))")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
