// swiftlint:disable missing_docs
struct SentryFeatureFlagEvaluation: Equatable {
    static let spanDataKeyPrefix = "flag.evaluation."

    let flag: String
    let result: SentryFeatureFlagValueContent

    static func spanDataKey(for flag: String) -> String {
        return "\(spanDataKeyPrefix)\(flag)"
    }

    var spanDataKey: String {
        return Self.spanDataKey(for: flag)
    }

    func serializeForContext() -> [String: Any] {
        return [
            "flag": flag,
            "result": result.serializedValue
        ]
    }

    func serializeForSpanData() -> [String: Any] {
        return [spanDataKey: result.serializedValue]
    }
}
// swiftlint:enable missing_docs
