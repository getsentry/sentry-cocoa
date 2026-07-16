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
        public var urlQueryParams: Bool

        /// - Parameter urlQueryParams: Include database query parameters. Defaults to `true`.
        public init(urlQueryParams: Bool = true) {
            self.urlQueryParams = urlQueryParams
        }

        /// Creates database collection options from a dictionary.
        @_spi(Private) public init(dictionary: [String: Any]) {
            self.init()

            if let urlQueryParams = SentryDictionaryDecoder.bool(dictionary, "urlQueryParams") {
                self.urlQueryParams = urlQueryParams
            }
        }
    }
}
#endif // SDK_V10
