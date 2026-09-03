import Foundation

// Crash-time screenshot capture is installed inside the SDK when SENTRY_CRASH_E2E is set
// (SentryKSCrash.CrashE2ETestHook). This type only logs so the app does not import SPI.
enum CrashE2EAttachmentsSetup {
    static func setupIfNeeded() {
        guard CrashE2ERuntime.configuration.scenario == .crashTimeAttachments else { return }
        NSLog("CrashE2E - crash-time-attachments uses the SDK SENTRY_CRASH_E2E screenshot hook")
    }
}
