import Foundation

enum StoredCrashReports {
    /// Both reporters store reports as JSON files inside a `Reports` directory under their own
    /// install root (`KSCrash/<bundle>` or `SentryCrash/<bundle>`).
    static func urls(in cacheRoot: URL) throws -> [URL] {
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

    /// Drain converts the report into an envelope and deletes `Reports/*.json`.
    /// Copy them first so raw `sentry_sdk_scope` / `user` layout stays inspectable.
    static func copyUndrained(
        from cacheRoot: URL,
        platform: String,
        scenario: Scenario,
        artifactsDir: URL
    ) throws {
        let reports = try urls(in: cacheRoot)
        guard !reports.isEmpty else {
            log("No stored crash report to copy before drain for \(platform)/\(scenario.rawValue).")
            return
        }

        for (index, report) in reports.enumerated() {
            let suffix = reports.count == 1
                ? "undrained.json"
                : "undrained-\(index + 1).json"
            let destination = artifactsDir.appendingPathComponent(
                "\(platform)-\(scenario.rawValue)-\(suffix)"
            )
            try FileManager.default.removeItemIfExists(at: destination)
            try FileManager.default.copyItem(at: report, to: destination)
            log("Copied undrained crash report: \(destination.path)")
        }
    }
}
