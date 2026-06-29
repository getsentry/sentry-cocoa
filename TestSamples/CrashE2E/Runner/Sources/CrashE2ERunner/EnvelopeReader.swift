import Foundation

struct ExceptionEventEnvelope {
    let sourceURL: URL
    let event: [String: Any]
}

enum EnvelopeReader {
    static func exceptionEvents(in cacheRoot: URL) throws -> [ExceptionEventEnvelope] {
        let sentryRoot = cacheRoot.appendingPathComponent("io.sentry", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sentryRoot.path) else {
            return []
        }

        let fileURLs = try envelopeFileURLs(in: sentryRoot)
        var events: [ExceptionEventEnvelope] = []

        for url in fileURLs {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
            for lineSubsequence in lines {
                let line = String(lineSubsequence).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                guard let object = try? JSONSerialization.jsonObject(with: data),
                      let event = object as? [String: Any],
                      isExceptionEvent(event) else { continue }
                events.append(ExceptionEventEnvelope(sourceURL: url, event: event))
            }
        }

        return events
    }

    private static func envelopeFileURLs(in sentryRoot: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sentryRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard url.path.contains("/envelopes/") else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                urls.append(url)
            }
        }
        return urls.sorted { $0.path < $1.path }
    }

    private static func isExceptionEvent(_ event: [String: Any]) -> Bool {
        guard let exception = event["exception"] as? [String: Any],
              let values = exception["values"] as? [Any] else {
            return false
        }
        return !values.isEmpty
    }

    static func writeEvent(_ event: [String: Any], to outputURL: URL) throws {
        try FileManager.default.ensureDirectory(at: outputURL.deletingLastPathComponent())
        let data = try JSONSerialization.data(withJSONObject: event, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: outputURL, options: [.atomic])
    }
}
