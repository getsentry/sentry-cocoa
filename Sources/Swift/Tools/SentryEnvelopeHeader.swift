@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryEnvelopeHeader: NSObject, Codable {
    /**
     * Initializes an @c SentryEnvelopeHeader object with the specified eventId.
     * @note Sets the @c sdkInfo from @c SentryMeta.
     * @param eventId The identifier of the event. Can be nil if no event in the envelope or attachment
     * related to event.
     */
    @objc public convenience init(id eventId: SentryId?) {
        self.init(id: eventId, traceContext: nil)
    }
    
    /**
     * Initializes a @c SentryEnvelopeHeader object with the specified @c eventId and @c traceContext.
     * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
     * attachment related to event.
     * @param traceContext Current trace state.
     */
    @objc public convenience init(id eventId: SentryId?, traceContext: TraceContext?) {
        self.init(id: eventId, sdkInfo: SentrySdkInfo.global(), traceContext: traceContext)
    }
    
    /**
     * Initializes a @c SentryEnvelopeHeader object with the specified @c eventId, @c skdInfo and
     * @c traceContext. It is recommended to use @c initWithId:traceContext: because it sets the
     * @c sdkInfo for you.
     * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
     * attachment related to event.
     * @param sdkInfo Describes the Sentry SDK. Can be @c nil for backwards compatibility. New
     * instances should always provide a version.
     * @param traceContext Current trace state.
     */
    @objc public
    init(id eventId: SentryId?, sdkInfo: SentrySdkInfo?, traceContext: TraceContext?) {
        self.eventId = eventId
        self.sdkInfo = sdkInfo
        self.trace = traceContext
    }
    
    @objc public static func empty() -> Self {
        Self(id: nil, traceContext: nil)
    }
    
    /**
     * The event identifier, if available.
     * An event id exist if the envelope contains an event of items within it are related. i.e
     * Attachments
     */
    @objc public var eventId: SentryId?
    @objc public var sdkInfo: SentrySdkInfo?
    @objc public var trace: TraceContext?
    
    /**
     * The timestamp when the event was sent from the SDK as string in RFC 3339 format. Used
     * for clock drift correction of the event timestamp. The time zone must be UTC.
     *
     * The timestamp should be generated as close as possible to the transmision of the event,
     * so that the delay between sending the envelope and receiving it on the server-side is
     * minimized.
     */
    @objc public var sentAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case eventId
        case sdkInfo
        case trace
        case sentAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let eventId = try container.decodeIfPresent(String.self, forKey: .eventId) {
            self.eventId = SentryId(uuidString: eventId)
        }
        self.sdkInfo = try container.decodeIfPresent(SentrySdkInfo.self, forKey: .sdkInfo)
        if let trace = try container.decodeIfPresent(TraceContextSwift.self, forKey: .trace) {
            self.trace = TraceContext(
                trace: SentryId(uuidString: trace.traceId),
                publicKey: trace.publicKey,
                releaseName: trace.release,
                environment: trace.environment,
                transaction: trace.transaction,
                sampleRate: trace.sampleRate,
                sampleRand: trace.sampleRand,
                sampled: trace.sampled,
                replayId: trace.replayId)
        }
        if let sentAt = try container.decodeIfPresent(String.self, forKey: .sentAt) {
            self.sentAt = sentry_fromIso8601String(sentAt)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(eventId?.sentryIdString, forKey: .eventId)
        try container.encodeIfPresent(sdkInfo, forKey: .sdkInfo)
        if let trace {
            let traceSwift = TraceContextSwift(traceId: trace.traceId.sentryIdString, publicKey: trace.publicKey, release: trace.releaseName, environment: trace.environment, transaction: trace.transaction, sampleRand: trace.sampleRand, sampleRate: trace.sampleRate, sampled: trace.sampled, replayId: trace.replayId)
            try container.encode(traceSwift, forKey: .trace)
        }
        if let sentAt {
            try container.encodeIfPresent(sentry_toIso8601String(sentAt), forKey: .sentAt)
        }
    }
}

struct TraceContextSwift: Codable {
    let traceId: String
    let publicKey: String
    let release: String?
    let environment: String?
    let transaction: String?
    let sampleRand: String?
    let sampleRate: String?
    let sampled: String?
    let replayId: String?
}
