// swiftlint:disable missing_docs
struct SentryFeatureFlagEvaluation: Equatable {
    private static let spanDataKeyPrefix = "flag.evaluation."

    let flag: String
    let result: SentryFeatureFlagValueContent

    var spanDataKey: String {
        return "\(Self.spanDataKeyPrefix)\(flag)"
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
