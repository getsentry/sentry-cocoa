protocol BatcherItem: Encodable {
    var attributes: [String: SentryAttribute] { get set }
    var traceId: SentryId { get set }
    var body: String { get }
}
