import Darwin
import Foundation
import Sentry

extension CrashE2ERuntime {
    /// Markers live next to the SDK cache so the runner finds them under the same root it reads
    /// envelopes from: the explicit `--cache-dir` on macOS, or the app container caches on iOS.
    static func cacheMarkerURL(named fileName: String) throws -> URL {
        if let cacheDirectoryPath = configuration.cacheDirectoryPath {
            return URL(fileURLWithPath: cacheDirectoryPath, isDirectory: true)
                .appendingPathComponent(fileName)
        }

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheURL = caches.first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return cacheURL.appendingPathComponent(fileName)
    }

    /// Records how the SDK classified the previous run on every drain launch, using the same
    /// public API an app would consult. The `sigterm` scenario asserts on it.
    static func writeLastRunMarkerIfNeeded() {
        guard configuration.scenario == .drain else { return }
        do {
            let markerURL = try cacheMarkerURL(named: "crash-e2e-last-run.json")
            let marker = ["last_run_status": lastRunStatusName(SentrySDK.lastRunStatus)]
            let data = try JSONSerialization.data(withJSONObject: marker, options: [.sortedKeys])
            try data.write(to: markerURL, options: [.atomic])
        } catch {
            NSLog("CrashE2E - failed to write last-run marker: \(error)")
            Darwin.abort()
        }
    }

    private static func lastRunStatusName(_ status: SentryLastRunStatus) -> String {
        switch status {
        case .unknown:
            return "unknown"
        case .didNotCrash:
            return "didNotCrash"
        case .didCrash:
            return "didCrash"
        @unknown default:
            return "unknown"
        }
    }
}
