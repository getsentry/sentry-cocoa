protocol BatcherItem: Encodable {
    var attributesMap: [String: SentryAttributeContent] { get set }
    var traceId: SentryId { get set }
    var body: String { get }
}
