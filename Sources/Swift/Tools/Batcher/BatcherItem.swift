protocol BatcherItem: Encodable {
    var attributesDict: [String: SentryAttributeContent] { get set }
    var traceId: SentryId { get set }
}
