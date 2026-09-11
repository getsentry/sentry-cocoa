import Darwin
import Foundation

/// Shared contract for the `sigterm` scenario. The app writes a ready marker after the SDK has
/// started so the runner knows the crash handlers are installed before it sends a real `SIGTERM`.
/// The drain launch then records whether the SDK classified the previous run as crashed.
enum SigtermScenarioConstants {
    static let readyMarkerFileName = "crash-e2e-sigterm-ready.marker"
    static let lastRunMarkerFileName = "crash-e2e-last-run.json"
    static let readyTimeout: TimeInterval = 20
    static let terminationTimeout: TimeInterval = 20
}

enum SigtermScenarioAsserter {
    static func waitForReadyMarker(at markerURL: URL, platform: String) throws {
        let deadline = Date().addingTimeInterval(SigtermScenarioConstants.readyTimeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: markerURL.path) {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        try fail("\(platform)/sigterm app did not write the ready marker at \(markerURL.path)")
    }

    static func sendSigterm(to pid: Int32, platform: String) throws {
        log("Sending SIGTERM to \(platform) pid \(pid).")
        guard Darwin.kill(pid, SIGTERM) == 0 else {
            try fail("\(platform)/sigterm failed to send SIGTERM to pid \(pid): \(String(cString: strerror(errno)))")
        }
    }

    /// Neither SentryCrash nor KSCrash may persist a report for SIGTERM. Check before the drain
    /// launch, because a drain would convert any stored report into an event and delete it.
    static func assertNoStoredCrashReports(cacheRoot: URL, platform: String) throws {
        let reports = try storedReportURLs(in: cacheRoot)
        guard reports.isEmpty else {
            try fail(
                "Expected no stored crash report for \(platform)/sigterm under \(cacheRoot.path), found: "
                    + reports.map(\.path).joined(separator: ", ")
            )
        }
        log("✅ \(platform)/sigterm no stored crash report.")
    }

    static func assertLastRunNotCrashed(cacheRoot: URL, platform: String) throws {
        let markerURL = cacheRoot.appendingPathComponent(SigtermScenarioConstants.lastRunMarkerFileName)
        guard FileManager.default.fileExists(atPath: markerURL.path) else {
            try fail("Expected last-run marker for \(platform)/sigterm at \(markerURL.path)")
        }
        let data = try Data(contentsOf: markerURL)
        guard let marker = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lastRunStatus = marker["last_run_status"] as? String else {
            try fail("Malformed last-run marker for \(platform)/sigterm at \(markerURL.path)")
        }
        // Require a positive "did not crash" classification: "unknown" would mean the crash
        // reporter never finished initializing and would hide a regression.
        guard lastRunStatus == "didNotCrash" else {
            try fail("Expected lastRunStatus didNotCrash after SIGTERM for \(platform)/sigterm, got \(lastRunStatus)")
        }
        log("✅ \(platform)/sigterm next launch classified as didNotCrash.")
    }

    /// Both reporters store reports as JSON files inside a `Reports` directory under their own
    /// install root (`KSCrash/<bundle>` or `SentryCrash/<bundle>`).
    private static func storedReportURLs(in cacheRoot: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: cacheRoot.path),
              let enumerator = FileManager.default.enumerator(
                  at: cacheRoot,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var reports: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "json",
                  url.deletingLastPathComponent().lastPathComponent == "Reports",
                  url.pathComponents.contains(where: { $0 == "KSCrash" || $0 == "SentryCrash" }) else {
                continue
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                reports.append(url)
            }
        }
        return reports.sorted { $0.path < $1.path }
    }
}
