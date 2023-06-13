import Foundation

@objcMembers
public class UrlSanitized: NSObject {
    public static let SENSITIVE_DATA_SUBSTITUTE = "[Filtered]"
    private var components: URLComponents?

    public var query: String? { components?.query }
    public var queryItems: [URLQueryItem]? { components?.queryItems }
    public var fragment: String? { components?.fragment }

    public init(URL url: URL) {
        components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if components?.user != nil {
            components?.user = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }

        if components?.password != nil {
            components?.password = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }
    }

    public var sanitizedUrl: String? {
        guard let result = self.components?.string else { return nil }
        guard let end = result.firstIndex(of: "?") ?? result.firstIndex(of: "#") else {
            return result
        }

        return String(result[result.startIndex..<end]).removingPercentEncoding
    }
}
