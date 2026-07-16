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
        guard var result = components?.string else { return nil }
#if SDK_V10
        let end = result.firstIndex(of: "#")
#else
        let end = result.firstIndex(of: "?") ?? result.firstIndex(of: "#")
#endif // SDK_V10
        if let end {
            result = String(result[result.startIndex..<end])
        }
        return result.removingPercentEncoding
    }

    public var sanitizedBaseUrl: String? {
        guard var result = components?.string else { return nil }
        if let end = result.firstIndex(of: "?") ?? result.firstIndex(of: "#") {
            result = String(result[result.startIndex..<end])
        }
        return result.removingPercentEncoding
    }
}
// swiftlint:enable missing_docs
