internal import _SentryPrivate
import Foundation

/// A fatal report the coordinator holds back, waiting for another source to report on the same
/// run.
struct SentryHeldFatalReport {
    let runId: SentryCurrentRun.ID
    let source: SentryEventSource
    let event: Event
    /// The crashed session of the run the report describes, or `nil` when that run had none.
    ///
    /// The SDK keeps one crashed session for the first fatal event of a launch. When the app
    /// crashes while a report is held, the next launch replaces that session with the one of the
    /// crashed run, so the held report keeps the session of its own run and is sent with it.
    var session: SentrySession?

    /// The report as the source submitted it. Attachments aren't kept, because the only source
    /// that is held, the watchdog termination integration, has none.
    var report: SentryEventSourceReport {
        SentryEventSourceReport(
            source: source,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: false),
            runId: runId,
            event: event,
            crashedSession: .carried(session)
        )
    }
}

// The file `SentryHeldFatalReportStore` keeps. `Event` and `SentrySession` aren't `Encodable`:
// they serialize to dictionaries, which are written as `JSONValue`. The event is read back
// through its own `Decodable` type, in the one pass that decodes the file.
extension SentryHeldFatalReport: Codable {
    private enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case source
        case event
        case session
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runId = try container.decode(SentryCurrentRun.ID.self, forKey: .runId)
        source = try container.decode(SentryEventSource.self, forKey: .source)
        let event = try container.decode(SentryEventDecodable.self, forKey: .event)
        // The event was complete when it was stored, so the scope of the current run must not add
        // its breadcrumbs, which it does for an event without any.
        event.breadcrumbs = event.breadcrumbs ?? []
        self.event = event
        // A session that can't be read anymore doesn't take the report with it.
        session = (try? container.decodeIfPresent(JSONValue.self, forKey: .session))
            .flatMap { $0.jsonObject as? [String: Any] }
            .flatMap { SentrySession(jsonObject: $0) }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runId, forKey: .runId)
        try container.encode(source, forKey: .source)
        try container.encode(Self.jsonValue(of: event.serialize(), codingPath: container.codingPath + [CodingKeys.event]), forKey: .event)
        if let session {
            try container.encode(Self.jsonValue(of: session.serializeForPersistence(), codingPath: container.codingPath + [CodingKeys.session]), forKey: .session)
        }
    }

    private static func jsonValue(of serialized: [String: Any], codingPath: [any CodingKey]) throws -> JSONValue {
        guard let value = JSONValue(jsonObject: serialized) else {
            throw EncodingError.invalidValue(serialized, EncodingError.Context(codingPath: codingPath, debugDescription: "The serialized dictionary holds a value JSON can't represent."))
        }
        return value
    }
}
