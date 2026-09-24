#if os(iOS) || (os(macOS) && CRASH_E2E_MACOS_APP)
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crash E2E")
                .font(.headline)
            Text("Scenario: \(CrashE2ERuntime.configuration.scenario.rawValue)")
            Text("Crash backend parity harness")
                .font(.caption)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 160)
    }
}
#endif
