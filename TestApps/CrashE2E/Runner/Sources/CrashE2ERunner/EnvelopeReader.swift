import Foundation

struct EnvelopeAttachment {
    let filename: String?
    let attachmentType: String?
    let payload: Data
}

struct ExceptionEventEnvelope {
    let sourceURL: URL
    let event: [String: Any]
    let attachments: [EnvelopeAttachment]
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
            let data = try Data(contentsOf: url)
            let items = envelopeItems(in: data)
            let attachments = items.compactMap(attachment(from:))
            for event in items.compactMap(exceptionEvent(from:)) {
                events.append(
                    ExceptionEventEnvelope(sourceURL: url, event: event, attachments: attachments)
                )
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

    private struct EnvelopeItem {
        let header: [String: Any]
        let payload: Data
    }

    private static func envelopeItems(in data: Data) -> [EnvelopeItem] {
        var offset = 0
        guard readLine(in: data, offset: &offset) != nil else { return [] }

        var items: [EnvelopeItem] = []
        while offset < data.count {
            guard let headerData = readLine(in: data, offset: &offset),
                  let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any]
            else {
                break
            }
            let length = header["length"] as? Int ?? 0
            guard offset + length <= data.count else { break }
            let payload = data.subdata(in: offset..<(offset + length))
            offset += length
            if offset < data.count, data[offset] == UInt8(ascii: "\n") {
                offset += 1
            }
            items.append(EnvelopeItem(header: header, payload: payload))
        }
        return items
    }

    private static func exceptionEvent(from item: EnvelopeItem) -> [String: Any]? {
        guard item.header["type"] as? String == "event",
              let object = try? JSONSerialization.jsonObject(with: item.payload),
              let event = object as? [String: Any],
              isExceptionEvent(event)
        else {
            return nil
        }
        return event
    }

    private static func attachment(from item: EnvelopeItem) -> EnvelopeAttachment? {
        guard item.header["type"] as? String == "attachment" else { return nil }
        return EnvelopeAttachment(
            filename: item.header["filename"] as? String,
            attachmentType: item.header["attachment_type"] as? String,
            payload: item.payload
        )
    }

    private static func readLine(in data: Data, offset: inout Int) -> Data? {
        guard offset < data.count else { return nil }
        if let newline = data[offset...].firstIndex(of: UInt8(ascii: "\n")) {
            let line = data[offset..<newline]
            offset = newline + 1
            return Data(line)
        }
        let line = data[offset...]
        offset = data.count
        return Data(line)
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
