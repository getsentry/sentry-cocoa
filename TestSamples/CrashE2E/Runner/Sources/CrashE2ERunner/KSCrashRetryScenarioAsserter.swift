import Foundation

struct KSCrashRetryScenarioConstants {
    static let markerA = "crash-e2e-kscrash-report-a"
    static let markerB = "crash-e2e-kscrash-report-b"
    static let appScenarioA = "kscrash-retry-report-a"
    static let appScenarioB = "kscrash-retry-report-b"
    static let retryableMarkerArgument =
        "--io.sentry.crash-e2e-kscrash-retryable-marker"
    static let processingCompleteMarkerArgument =
        "--io.sentry.crash-e2e-kscrash-processing-complete"
}

enum KSCrashRetryScenarioAsserter {
    static func assertPendingReports(_ expectedMarkers: [String], cacheRoot: URL,
                                     platform: String, phase: String) throws {
        let reports = try storedReports(in: cacheRoot)
        let actualMarkers = try reports.map { report -> String in
            let matches = [
                KSCrashRetryScenarioConstants.markerA,
                KSCrashRetryScenarioConstants.markerB
            ].filter { report.contents.contains($0) }
            guard matches.count == 1, let marker = matches.first else {
                try fail(
                    "Expected one KSCrash retry marker in stored report \(report.url.path), found \(matches)"
                )
            }
            return marker
        }

        guard actualMarkers.sorted() == expectedMarkers.sorted() else {
            try fail(
                "Expected pending KSCrash reports \(expectedMarkers.sorted()) for \(platform)/\(phase), "
                    + "found \(actualMarkers.sorted()) under \(cacheRoot.path)"
            )
        }
        log("✅ \(platform)/\(phase) pending KSCrash reports: \(actualMarkers.sorted())")
    }

    static func assertEnvelopeEvents(_ expectedMarkers: [String], cacheRoot: URL,
                                     platform: String, phase: String,
                                     artifactsDir: URL) throws {
        let events = try EnvelopeReader.exceptionEvents(in: cacheRoot)
        let markedEvents = try events.map { envelope -> (marker: String, event: [String: Any]) in
            let contexts = envelope.event["contexts"] as? [String: Any]
            let retryContext = contexts?["crash_e2e_kscrash_retry"] as? [String: Any]
            guard let marker = retryContext?["report"] as? String else {
                try fail(
                    "Expected CrashE2E KSCrash marker in envelope event from \(envelope.sourceURL.path)"
                )
            }
            return (marker, envelope.event)
        }
        let actualMarkers = markedEvents.map(\.marker)

        guard actualMarkers.sorted() == expectedMarkers.sorted() else {
            try fail(
                "Expected envelope markers \(expectedMarkers.sorted()) for \(platform)/\(phase), "
                    + "found \(actualMarkers.sorted()) under \(cacheRoot.path)"
            )
        }

        for markedEvent in markedEvents {
            let suffix: String
            switch markedEvent.marker {
            case KSCrashRetryScenarioConstants.markerA:
                suffix = "a"
            case KSCrashRetryScenarioConstants.markerB:
                suffix = "b"
            default:
                try fail(
                    "Unexpected KSCrash retry event marker \(markedEvent.marker) for \(platform)/\(phase)"
                )
            }
            let eventPath = artifactsDir.appendingPathComponent(
                "\(platform)-kscrash-per-report-retry-\(suffix)-event.json"
            )
            try EnvelopeReader.writeEvent(markedEvent.event, to: eventPath)
        }

        log("✅ \(platform)/\(phase) envelope markers: \(actualMarkers.sorted())")
    }

    static func assertProcessingCompleted(at markerURL: URL, platform: String,
                                          phase: String) throws {
        guard FileManager.default.fileExists(atPath: markerURL.path) else {
            try fail(
                "Expected KSCrash processing completion marker for \(platform)/\(phase) at \(markerURL.path)"
            )
        }
    }

    private struct StoredReport {
        let url: URL
        let contents: String
    }

    private static func storedReports(in cacheRoot: URL) throws -> [StoredReport] {
        guard FileManager.default.fileExists(atPath: cacheRoot.path),
              let enumerator = FileManager.default.enumerator(
                  at: cacheRoot,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var reports: [StoredReport] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "json",
                  url.deletingLastPathComponent().lastPathComponent == "Reports",
                  url.pathComponents.contains("KSCrash") else {
                continue
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }
            reports.append(
                StoredReport(
                    url: url,
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            )
        }
        return reports.sorted { $0.url.path < $1.url.path }
    }
}
