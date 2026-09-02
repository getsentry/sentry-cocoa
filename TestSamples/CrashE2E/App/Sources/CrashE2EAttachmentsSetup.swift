import Foundation

// Installs a synthetic crash-time screenshot provider for the crash-time-attachments E2E scenario.
// Guarded by SENTRY_CRASH_E2E so the dependency on internal SDK API never enters production builds.
enum CrashE2EAttachmentsSetup {
    static func setupIfNeeded() {
        guard CrashE2ERuntime.configuration.scenario == .crashTimeAttachments else { return }
        #if SDK_V10 && SENTRY_CRASH_E2E
        SentryKSCrash.CrashE2ETestHook.installSyntheticScreenshotProvider()
        NSLog("CrashE2E - installed synthetic screenshot provider for crash-time-attachments")
        #endif
    }
}
