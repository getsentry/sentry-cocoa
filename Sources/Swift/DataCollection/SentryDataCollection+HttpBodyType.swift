extension SentryDataCollection {
    /// Identifies the direction and role of an HTTP body for collection purposes.
    ///
    /// Used by ``SentryDataCollection/Options/httpBodies`` to specify which body types to collect.
    /// An empty option set disables body collection entirely; ``all`` (the default) collects all types.
    ///
    /// - SeeAlso: [Data Collection Spec — Body Type Collection](https://develop.sentry.dev/sdk/foundations/client/data-collection/#option-types)
    public struct HttpBodyType: OptionSet, Hashable, Sendable {
        /// The raw integer value of the option set.
        public let rawValue: Int

        /// Creates a body type from a raw integer value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Body of an incoming HTTP request (server-side).
        public static let incomingRequest = HttpBodyType(rawValue: 1 << 0)

        /// Body of an outgoing HTTP request (client-side).
        public static let outgoingRequest = HttpBodyType(rawValue: 1 << 1)

        /// Body of an incoming HTTP response (client-side).
        public static let incomingResponse = HttpBodyType(rawValue: 1 << 2)

        /// Body of an outgoing HTTP response (server-side).
        public static let outgoingResponse = HttpBodyType(rawValue: 1 << 3)

        /// All body types valid for the platform.
        public static let all: HttpBodyType = [.incomingRequest, .outgoingRequest, .incomingResponse, .outgoingResponse]
    }
}
