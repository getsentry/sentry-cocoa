import Darwin
import Foundation
import SentrySwift

extension CrashE2ERuntime {
    static func scheduleCrashAfterProcessingCompletesIfRequested() {
        let triggerCrash = {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                CrashE2ECrashTriggers.trigger(configuration.scenario)
            }
        }

        guard configuration.processingCompleteMarkerPath != nil else {
            triggerCrash()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            waitForProcessingCompletionOrAbort()
            triggerCrash()
        }
    }

    static func scheduleExitAfterProcessingCompletes() {
        DispatchQueue.global(qos: .userInitiated).async {
            waitForProcessingCompletionOrAbort()
            DispatchQueue.main.async {
                NSLog("CrashE2E - KSCrash report processing completed")
                SentrySDK.close()
                Darwin.exit(0)
            }
        }
    }

    static func waitForProcessingCompletionOrAbort() {
        guard let markerPath = configuration.processingCompleteMarkerPath else {
            return
        }

        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: markerPath) {
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        NSLog("CrashE2E - timed out waiting for KSCrash report processing marker: \(markerPath)")
        Darwin.abort()
    }
}
