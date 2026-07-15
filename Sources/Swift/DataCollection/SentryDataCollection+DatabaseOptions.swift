#if SDK_V10
extension SentryDataCollection {
    /// Controls collection of database query parameters.
    ///
    /// When disabled, parameter values are either omitted or replaced with `[Filtered]`.
    ///
    /// - SeeAlso: [Data Collection Spec — `database`](https://develop.sentry.dev/sdk/foundations/client/data-collection/#datacollection-options)
    public struct DatabaseCollectionOptions: Equatable {

        /// Include parameters/arguments passed to database queries.
        ///
        /// Defaults to `true`.
        public var queryParams: Bool

        /// - Parameter queryParams: Include database query parameters. Defaults to `true`.
        public init(queryParams: Bool = true) {
            self.queryParams = queryParams
        }

        /// Creates database collection options from a dictionary.
        @_spi(Private) public init(dictionary: [String: Any]) {
            self.init()

            if let queryParams = SentryDictionaryDecoder.bool(dictionary, "queryParams") {
                self.queryParams = queryParams
            }
        }
    }
}
#endif // SDK_V10
