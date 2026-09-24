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
}
