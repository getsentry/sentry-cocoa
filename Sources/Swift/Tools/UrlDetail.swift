import Foundation

@objcMembers
public class UrlDetail: NSObject {
    public static let SENSITIVE_DATA_SUBSTITUTE = "[Filtered]"
    private var components: URLComponents?

    public var scheme: String? { components?.scheme }
    public var host: String? { components?.host }
    public var port: Int? { components?.port }
    public var path: String? { components?.path }
    public var query: String? { components?.query }
    public var queryItems: [URLQueryItem]? { components?.queryItems }
    public var fragment: String? { components?.fragment }

    public init(URL url: URL) {
        components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if components?.user != nil {
            components?.user = UrlDetail.SENSITIVE_DATA_SUBSTITUTE
        }

        if components?.password != nil {
            components?.password = UrlDetail.SENSITIVE_DATA_SUBSTITUTE
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
