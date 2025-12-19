protocol BatcherItem: Encodable {
    var attributeMap: [String: SentryAttributeValue] { get set }
    var traceId: SentryId { get set }
}
