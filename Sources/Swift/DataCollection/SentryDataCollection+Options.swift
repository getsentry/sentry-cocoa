#if SDK_V10
extension SentryDataCollection {
    /// Configuration for what data the SDK collects automatically.
    ///
    /// All properties have spec-defined defaults. Users supply only the options they want to override;
    /// omitted fields use the documented defaults.
    ///
    /// Data explicitly set by the user on the scope (via `SentrySDK.setUser()`, `scope.setTag()`, etc.)
    /// is **not** gated by these options and is always attached to outgoing telemetry.
    ///
    /// - SeeAlso: [Data Collection Spec](https://develop.sentry.dev/sdk/foundations/client/data-collection/)
    public struct Options: Equatable {

        /// Automatically populate `user.*` fields (`user.id`, `user.email`, `user.username`, `user.ip_address`) from auto-instrumentation
        /// (e.g., inferring `user.ip_address` from an incoming HTTP request, or deriving user identity from framework session/auth context).
        ///
        /// Does **not** gate data explicitly set via `SentrySDK.setUser()`, which is always attached.
        ///
        /// Defaults to `true`.
        public var userInfo: Bool

        /// Controls cookie collection. All cookie key names are always included; the SDK scrubs values
        /// for keys matching the sensitive denylist or custom allow/deny terms.
        ///
        /// Defaults to ``SentryDataCollection/KeyValueCollectionBehavior/denyList(terms:)`` (built-in sensitive
        /// denylist only).
        public var cookies: SentryDataCollection.KeyValueCollectionBehavior

        /// Controls HTTP header collection independently for request and response directions.
        ///
        /// Defaults to ``SentryDataCollection/HttpHeaderCollectionOptions/init(request:response:)`` with both
        /// directions set to `.denyList()`.
        public var httpHeaders: SentryDataCollection.HttpHeaderCollectionOptions

        /// Body types to collect. An empty option set disables body collection entirely.
        ///
        /// Defaults to ``SentryDataCollection/HttpBodyType/all``.
        public var httpBodies: SentryDataCollection.HttpBodyType

        /// Controls URL query parameter filtering. All query parameter key names are always included;
        /// the SDK scrubs values for keys matching the sensitive denylist or custom allow/deny terms.
        ///
        /// Defaults to ``SentryDataCollection/KeyValueCollectionBehavior/denyList(terms:)`` (built-in sensitive
        /// denylist only).
        public var urlQueryParams: SentryDataCollection.KeyValueCollectionBehavior

        /// Creates a data collection configuration with spec-defined defaults.
        ///
        /// All parameters are optional and default to the values defined in the
        /// [Data Collection Spec](https://develop.sentry.dev/sdk/foundations/client/data-collection/#datacollection-options).
        ///
        /// - Parameters:
        ///   - userInfo: Automatically populate `user.*` fields. Defaults to `true`.
        ///   - cookies: Cookie collection behavior. Defaults to `.denyList()`.
        ///   - httpHeaders: HTTP header collection for request/response. Defaults to both `.denyList()`.
        ///   - httpBodies: Body types to collect. Defaults to `.all`; pass `[]` to disable.
        ///   - urlQueryParams: Query parameter collection behavior. Defaults to `.denyList()`.
        public init(
            userInfo: Bool = true,
            cookies: SentryDataCollection.KeyValueCollectionBehavior = .denyList(),
            httpHeaders: SentryDataCollection.HttpHeaderCollectionOptions = .init(),
            httpBodies: SentryDataCollection.HttpBodyType = .all,
            urlQueryParams: SentryDataCollection.KeyValueCollectionBehavior = .denyList()
        ) {
            self.userInfo = userInfo
            self.cookies = cookies
            self.httpHeaders = httpHeaders
            self.httpBodies = httpBodies
            self.urlQueryParams = urlQueryParams
        }

        /// Creates data collection options from a dictionary.
        @_spi(Private) public init(dictionary: [String: Any]) {
            self.init()

            if let userInfo = SentryDictionaryDecoder.bool(dictionary, "userInfo") {
                self.userInfo = userInfo
            }
            if let cookies = SentryDictionaryDecoder.dictionary(dictionary, "cookies") {
                self.cookies = SentryDataCollection.KeyValueCollectionBehavior(dictionary: cookies)
            }
            if let httpHeaders = SentryDictionaryDecoder.dictionary(dictionary, "httpHeaders") {
                self.httpHeaders = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: httpHeaders)
            }
            if let httpBodies = SentryDictionaryDecoder.strings(dictionary, "httpBodies") {
                self.httpBodies = SentryDataCollection.HttpBodyType(strings: httpBodies)
            }
            if let urlQueryParams = SentryDictionaryDecoder.dictionary(dictionary, "urlQueryParams") {
                self.urlQueryParams = SentryDataCollection.KeyValueCollectionBehavior(dictionary: urlQueryParams)
            }
        }
    }
}
#endif // SDK_V10
