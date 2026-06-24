// swiftlint:disable missing_docs
enum SentryFeatureFlagValueContent: Equatable {
    case boolean(Bool)

    var serializedValue: Any {
        switch self {
        case .boolean(let value):
            return value
        }
    }
}
// swiftlint:enable missing_docs
