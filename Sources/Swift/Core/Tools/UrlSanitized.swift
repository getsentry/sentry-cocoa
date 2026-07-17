// swiftlint:disable missing_docs
import Foundation

@objcMembers
@_spi(Private) public final class UrlSanitized: NSObject {

    // MARK: - Constants

    static let SENSITIVE_DATA_SUBSTITUTE = "[Filtered]"

    // MARK: - Properties

    private let wrapped: URL
#if SDK_V10
    private let urlQueryParamsBehavior: SentryDataCollection.KeyValueCollectionBehavior
#endif // SDK_V10

    // MARK: - Initializers

#if SDK_V10
    public init(URL url: URL, options: SentryDataCollection.Options) {
        self.wrapped = url
        self.urlQueryParamsBehavior = options.urlQueryParams
    }

    @_spi(Private) @objc(initWithURL:options:)
    public convenience init(URL url: URL, options: SentryDataCollectionObjCOptions) {
        self.init(URL: url, options: options.wrapped)
    }
#else
    public init(URL url: URL) {
        self.wrapped = url
    }
#endif // SDK_V10

    // MARK: - Accessors

    public var sanitizedUrl: String? {
        guard var components else { return nil }

#if !SDK_V10
        // The current implementation of the sanitized url is including query parameters, which should not be included
        // according to the data collection specification shipped with V10
        components.queryItems = nil
#endif // !SDK_V10
        components.fragment = nil

        return decodedString(from: components)
    }

    public var sanitizedBaseUrl: String? {
        guard var components else { return nil }

        components.queryItems = nil
        components.fragment = nil

        return decodedString(from: components)
    }

    public var query: String? {
        components?.query
    }

    public var queryItems: [URLQueryItem]? {
        components?.queryItems
    }

    public var fragment: String? {
        components?.fragment
    }

    // MARK: - Helpers

    private func decodedString(from components: URLComponents) -> String? {
        guard let string = components.string else { return nil }
        return string.removingPercentEncoding ?? string
    }

    private var components: URLComponents? {
        // Due to a bug in iOS 17 where storing the URLComponents in an optional property will cause the
        // `components.password = "[Filtered]"` to be reverted to the actual password by `components.queryItems = nil`
        // the components are NOT stored and always created on access.
        guard var components = URLComponents(url: wrapped, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if components.user != nil {
            components.user = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }
        if components.password != nil {
            components.password = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }

#if SDK_V10
        filterQueryItems(&components)
#endif // SDK_V10

        return components
    }

#if SDK_V10
    private func filterQueryItems(_ components: inout URLComponents) {
        guard components.percentEncodedQuery != nil else {
            return
        }

        if urlQueryParamsBehavior == .off {
            components.queryItems = nil
            return
        }

        guard components.query != nil, let queryItems = components.queryItems else {
            // If the query is set but cannot be parsed into query items, it is considered unparseable.
            // This can happen if the query contains invalid percent encoding or other malformed data.
            // In this case, we cannot filter individual query items, so we replace the entire query with
            // a placeholder to indicate that sensitive data has been filtered.
            components.queryItems = [URLQueryItem(name: Self.SENSITIVE_DATA_SUBSTITUTE, value: nil)]
            return
        }

        components.queryItems = queryItems.map { item in
            let originalValue = item.value ?? ""
            let filteredValue = SentryDataCollection.KeyValueFilter.filter(
                [item.name: originalValue],
                behavior: urlQueryParamsBehavior
            )[item.name]

            return URLQueryItem(
                name: item.name,
                value: filteredValue == originalValue ? item.value : filteredValue
            )
        }
    }
#endif // SDK_V10
}
// swiftlint:enable missing_docs
