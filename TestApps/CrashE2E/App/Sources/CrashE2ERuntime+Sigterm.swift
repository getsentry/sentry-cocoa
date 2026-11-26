import Darwin
import Foundation

extension CrashE2ERuntime {
    /// Give the runner ample time to observe the ready marker and deliver the signal.
    private static let sigtermWaitTimeout: TimeInterval = 30

    /// SIGTERM is delivered by the runner, never raised from inside the app, so the process only
    /// signals readiness and then idles until the signal terminates it.
    static func waitForExternalSigterm() {
        NSLog("CrashE2E - waiting for an external SIGTERM")
        writeSigtermReadyMarker()
        DispatchQueue.main.asyncAfter(deadline: .now() + sigtermWaitTimeout) {
            abortBecauseSigtermNeverArrived()
        }
    }

    static func waitForExternalSigtermSynchronously() -> Never {
        NSLog("CrashE2E - waiting synchronously for an external SIGTERM")
        writeSigtermReadyMarker()
        Thread.sleep(forTimeInterval: sigtermWaitTimeout)
        abortBecauseSigtermNeverArrived()
    }

    /// Written after SentrySDK.start so the runner only sends SIGTERM once the crash handlers are
    /// installed. Anything else would test the default signal disposition, not the SDK.
    private static func writeSigtermReadyMarker() {
        do {
            let markerURL = try cacheMarkerURL(named: "crash-e2e-sigterm-ready.marker")
            try Data().write(to: markerURL, options: [.atomic])
        } catch {
            NSLog("CrashE2E - failed to write SIGTERM ready marker: \(error)")
            Darwin.abort()
        }
    }

    private static func abortBecauseSigtermNeverArrived() -> Never {
        NSLog("CrashE2E - SIGTERM did not arrive within \(sigtermWaitTimeout)s")
        Darwin.abort()
    }
}
