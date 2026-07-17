// swiftlint:disable missing_docs
import Foundation

@objcMembers
@_spi(Private) public final class UrlSanitized: NSObject {
    static let SENSITIVE_DATA_SUBSTITUTE = "[Filtered]"
    private var components: URLComponents?

    public var query: String? { components?.query }
    public var queryItems: [URLQueryItem]? { components?.queryItems }
    public var fragment: String? { components?.fragment }

    private init(url: URL) {
        components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if components?.user != nil {
            components?.user = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }

        if components?.password != nil {
            components?.password = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }
    }

#if !SDK_V10
    public convenience init(URL url: URL) {
        self.init(url: url)
    }
#else
    public convenience init(URL url: URL, options: SentryDataCollection.Options) {
        self.init(url: url)
        filterQueryItems(behavior: options.urlQueryParams)
    }

    private func filterQueryItems(
        behavior: SentryDataCollection.KeyValueCollectionBehavior
    ) {
        guard components?.percentEncodedQuery != nil else {
            return
        }

        if behavior == .off {
            components?.queryItems = nil
            return
        }

        guard components?.query != nil, let queryItems = components?.queryItems else {
            // If the query is set but cannot be parsed into query items, it is considered unparseable.
            // This can happen if the query contains invalid percent encoding or other malformed data.
            // In this case, we cannot filter individual query items, so we replace the entire query with
            // a placeholder to indicate that sensitive data has been filtered.
            components?.queryItems = [URLQueryItem(name: Self.SENSITIVE_DATA_SUBSTITUTE, value: nil)]
            return
        }

        components?.queryItems = queryItems.map { item in
            let originalValue = item.value ?? ""
            let filteredValue = SentryDataCollection.KeyValueFilter.filter(
                [item.name: originalValue],
                behavior: behavior
            )[item.name]

            return URLQueryItem(
                name: item.name,
                value: filteredValue == originalValue ? item.value : filteredValue
            )
        }
    }

    @_spi(Private) @objc(initWithURL:options:)
    public convenience init(URL url: URL, options: SentryDataCollectionObjCOptions) {
        self.init(URL: url, options: options.wrapped)
    }
#endif // SDK_V10

    public var sanitizedUrl: String? {
        guard var components else { return nil }

#if !SDK_V10
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

    private func decodedString(from components: URLComponents) -> String? {
        guard let string = components.string else { return nil }
        return string.removingPercentEncoding ?? string
    }
}
// swiftlint:enable missing_docs
