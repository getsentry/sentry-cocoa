#if SDK_V10
extension SentryDataCollection {
    /// Applies the key-value filtering rules from the Sentry Data Collection candidate specification
    /// version 0.6.0.
    enum KeyValueFilter {
        private static let filteredValue = "[Filtered]"
        private static let sensitiveTerms = [
            "auth", "token", "secret", "password", "passwd", "pwd", "key", "jwt", "bearer",
            "sso", "saml", "csrf", "xsrf", "credentials", "session", "sid", "identity"
        ]

        static func filter(
            _ values: [String: String],
            behavior: SentryDataCollection.KeyValueCollectionBehavior
        ) -> [String: String] {
            switch behavior {
            case .off:
                return [:]
            case .denyList(let terms):
                let deniedTerms = sensitiveTerms + terms.map { $0.lowercased() }
                return values.mapValues { key, value in
                    matches(key: key, terms: deniedTerms) ? filteredValue : value
                }
            case .allowList(let terms):
                let allowedTerms = terms.map { $0.lowercased() }
                return values.mapValues { key, value in
                    guard !matches(key: key, terms: sensitiveTerms) else {
                        return filteredValue
                    }
                    return matches(key: key, terms: allowedTerms) ? value : filteredValue
                }
            }
        }

        private static func matches(key: String, terms: [String]) -> Bool {
            let lowercasedKey = key.lowercased()
            return terms.contains { lowercasedKey.contains($0) }
        }
    }
}

private extension Dictionary where Key == String, Value == String {
    func mapValues(_ transform: (Key, Value) -> Value) -> Self {
        reduce(into: [:]) { result, pair in
            result[pair.key] = transform(pair.key, pair.value)
        }
    }
}
#endif // SDK_V10
