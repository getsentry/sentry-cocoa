extension SentryDataCollection {
    /// Controls collection of GraphQL documents and variables.
    ///
    /// Both properties default to `true`.
    ///
    /// - SeeAlso: [Data Collection Spec — `graphql`](https://develop.sentry.dev/sdk/foundations/client/data-collection/#datacollection-options)
    public struct GraphQLCollectionOptions: Equatable {

        /// Collect the GraphQL document (query/mutation/subscription string).
        ///
        /// Defaults to `true`.
        public var document: Bool

        /// Collect the variables passed to GraphQL operations.
        ///
        /// Defaults to `true`.
        public var variables: Bool

        /// - Parameters:
        ///   - document: Collect GraphQL documents. Defaults to `true`.
        ///   - variables: Collect GraphQL variables. Defaults to `true`.
        public init(document: Bool = true, variables: Bool = true) {
            self.document = document
            self.variables = variables
        }

        /// Creates GraphQL collection options from a dictionary.
        @_spi(Private) public init(dictionary: [String: Any]) {
            self.init()

            if let document = SentryDataCollection.DictionaryDecoder.bool(dictionary, "document") {
                self.document = document
            }
            if let variables = SentryDataCollection.DictionaryDecoder.bool(dictionary, "variables") {
                self.variables = variables
            }
        }

    }
}
