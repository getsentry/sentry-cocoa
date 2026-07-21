#if SDK_V10
extension SentryDataCollection {
    /// Controls HTTP header collection independently for request and response directions.
    ///
    /// Each direction supports the same key-value collection modes described in
    /// ``SentryDataCollection/KeyValueCollectionBehavior``. Both default to
    /// ``SentryDataCollection/KeyValueCollectionBehavior/denyList(terms:)`` (built-in sensitive denylist only).
    ///
    /// - SeeAlso: [Data Collection Spec — HTTP Header Collection](https://develop.sentry.dev/sdk/foundations/client/data-collection/#option-types)
    public struct HttpHeaderCollectionOptions: Equatable {

        /// Controls collection of **request** header values.
        ///
        /// Defaults to ``SentryDataCollection/KeyValueCollectionBehavior/denyList(terms:)`` — all header names
        /// are included; values for keys matching the sensitive denylist are replaced with `[Filtered]`.
        public var request: SentryDataCollection.KeyValueCollectionBehavior

        /// Controls collection of **response** header values.
        ///
        /// Defaults to ``SentryDataCollection/KeyValueCollectionBehavior/denyList(terms:)`` — all header names
        /// are included; values for keys matching the sensitive denylist are replaced with `[Filtered]`.
        public var response: SentryDataCollection.KeyValueCollectionBehavior

        /// - Parameters:
        ///   - request: Collection behavior for request headers. Defaults to `.denyList()`.
        ///   - response: Collection behavior for response headers. Defaults to `.denyList()`.
        public init(
            request: SentryDataCollection.KeyValueCollectionBehavior = .denyList(),
            response: SentryDataCollection.KeyValueCollectionBehavior = .denyList()
        ) {
            self.request = request
            self.response = response
        }

        /// Creates HTTP header collection options from a dictionary.
        @_spi(Private) public init(dictionary: [String: Any]) {
            self.init()

            if let request = SentryDictionaryDecoder.dictionary(dictionary, "request") {
                self.request = SentryDataCollection.KeyValueCollectionBehavior(dictionary: request)
            }
            if let response = SentryDictionaryDecoder.dictionary(dictionary, "response") {
                self.response = SentryDataCollection.KeyValueCollectionBehavior(dictionary: response)
            }
        }
    }
}
#endif // SDK_V10
