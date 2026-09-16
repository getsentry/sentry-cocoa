import Foundation

enum RethrownNSExceptionAsserter {
    private static let markerFileName = "crash-e2e-uncaught-nsexception.marker"

    static func assertCrashLaunchEvidenceIfNeeded(
        scenario: Scenario,
        cacheRoot: URL,
        platform: String,
        artifactsDir: URL
    ) throws {
        guard scenario == .nsExceptionRethrow else { return }

        let markerURL = cacheRoot.appendingPathComponent(markerFileName)
        let markerContents = try String(contentsOf: markerURL, encoding: .utf8)
        guard markerContents.contains("uncaught-handler-called") else {
            try fail("Expected the chained NSUncaughtExceptionHandler to run for \(platform)/\(scenario.rawValue)")
        }

        let matchingReports = try storedReportURLs(in: cacheRoot).filter { reportURL in
            let contents = try String(contentsOf: reportURL, encoding: .utf8)
            return contents.contains("CrashE2ERethrownNSException")
                && contents.contains("ns-exception-rethrow")
                && contents.contains("nsexception")
        }
        guard matchingReports.count == 1 else {
            try fail(
                "Expected one persisted NSException report before drain for "
                    + "\(platform)/\(scenario.rawValue), found \(matchingReports.map(\.path))"
            )
        }
        let rawReportURL = matchingReports[0]

        let artifactURL = artifactsDir.appendingPathComponent(
            "\(platform)-\(scenario.rawValue)-raw-report.json"
        )
        try? FileManager.default.removeItem(at: artifactURL)
        try FileManager.default.copyItem(at: rawReportURL, to: artifactURL)
        log("✅ \(platform)/\(scenario.rawValue) uncaught handler ran and raw NSException report was persisted.")
    }

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
                  url.deletingLastPathComponent().lastPathComponent == "Reports" else {
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
