import Sentry

#if os(iOS)
import SwiftUI

@main
struct CrashE2EApp: App {
    @State private var didTriggerScenario = false

    init() {
        CrashE2ERuntime.startSDK()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    guard !didTriggerScenario else { return }
                    didTriggerScenario = true
                    CrashE2ERuntime.runSelectedScenario()
                }
        }
    }
}
#elseif os(macOS) && CRASH_E2E_MACOS_APP
import AppKit
import SwiftUI

final class CrashE2EMacOSAppDelegate: NSObject, NSApplicationDelegate {
    private var didTriggerScenario = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !didTriggerScenario else { return }
        didTriggerScenario = true
        CrashE2ERuntime.runSelectedScenario()
    }
}

@main
struct CrashE2EMacOSApp: App {
    @NSApplicationDelegateAdaptor(CrashE2EMacOSAppDelegate.self) private var appDelegate

    init() {
        CrashE2ERuntime.startSDK()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#elseif os(macOS) && CRASH_E2E_MACOS_CLI
@main
struct CrashE2ECommandLineApp {
    static func main() {
        CrashE2ERuntime.startSDK()
        CrashE2ERuntime.runSelectedScenarioSynchronously()
    }
}
#endif
