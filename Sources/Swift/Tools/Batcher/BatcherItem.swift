protocol BatcherItem: Encodable {
    var attributesMap: [String: SentryAttributeValue] { get set }
    var traceId: SentryId { get set }
    var body: String { get }
}
