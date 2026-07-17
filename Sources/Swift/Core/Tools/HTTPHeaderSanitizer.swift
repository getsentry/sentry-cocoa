// swiftlint:disable missing_docs
import Foundation

#if SDK_V10
@objcMembers
@_spi(Private) public final class HTTPHeaderSanitizationResult: NSObject {
    public let headers: [String: String]
    public let cookies: [String: String]

    init(headers: [String: String], cookies: [String: String]) {
        self.headers = headers
        self.cookies = cookies
    }
}

@objcMembers
@_spi(Private) public final class HTTPHeaderSanitizer: NSObject {
    public static func sanitizeHeaders(
        _ headers: [String: String],
        headerBehavior: SentryDataCollection.KeyValueCollectionBehavior,
        cookieBehavior: SentryDataCollection.KeyValueCollectionBehavior
    ) -> HTTPHeaderSanitizationResult {
        var regularHeaders: [String: String] = [:]
        var cookies: [String: String] = [:]

        for (name, value) in headers {
            switch name.lowercased() {
            case "cookie":
                collectCookies(
                    from: value,
                    isSetCookie: false,
                    name: name,
                    headerBehavior: headerBehavior,
                    cookieBehavior: cookieBehavior,
                    regularHeaders: &regularHeaders,
                    cookies: &cookies
                )
            case "set-cookie":
                collectCookies(
                    from: value,
                    isSetCookie: true,
                    name: name,
                    headerBehavior: headerBehavior,
                    cookieBehavior: cookieBehavior,
                    regularHeaders: &regularHeaders,
                    cookies: &cookies
                )
            default:
                regularHeaders[name] = value
            }
        }

        return HTTPHeaderSanitizationResult(
            headers: SentryDataCollection.KeyValueFilter.filter(
                regularHeaders,
                behavior: headerBehavior
            ),
            cookies: cookies
        )
    }

    private static func collectCookies(
        from value: String,
        isSetCookie: Bool,
        name: String,
        headerBehavior: SentryDataCollection.KeyValueCollectionBehavior,
        cookieBehavior: SentryDataCollection.KeyValueCollectionBehavior,
        regularHeaders: inout [String: String],
        cookies: inout [String: String]
    ) {
        guard cookieBehavior != .off else {
            return
        }

        guard let parsedCookies = parseCookies(value, isSetCookie: isSetCookie) else {
            if headerBehavior != .off {
                regularHeaders[name] = "[Filtered]"
            }
            return
        }

        cookies.merge(
            SentryDataCollection.KeyValueFilter.filter(parsedCookies, behavior: cookieBehavior),
            uniquingKeysWith: { _, last in last }
        )
    }

    private static func parseCookies(_ value: String, isSetCookie: Bool) -> [String: String]? {
        let cookieValues: [Substring]
        if isSetCookie {
            cookieValues = [value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]]
        } else {
            cookieValues = value.split(separator: ";", omittingEmptySubsequences: false)
        }

        var result: [String: String] = [:]
        for cookieValue in cookieValues {
            let pair = cookieValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pair.isEmpty, let separatorIndex = pair.firstIndex(of: "=") else {
                return nil
            }

            let name = pair[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return nil
            }

            let value = String(pair[pair.index(after: separatorIndex)...])
            result[name] = value
        }

        return result.isEmpty ? nil : result
    }
}
#else
@objcMembers
@_spi(Private) public final class HTTPHeaderSanitizer: NSObject {
    public static func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        let _securityHeaders = Set([
            "X-FORWARDED-FOR", "AUTHORIZATION", "COOKIE", "SET-COOKIE", "X-API-KEY", "X-REAL-IP",
            "REMOTE-ADDR", "FORWARDED", "PROXY-AUTHORIZATION", "X-CSRF-TOKEN", "X-CSRFTOKEN",
            "X-XSRF-TOKEN"
        ])

        return headers.filter { !_securityHeaders.contains($0.key.uppercased()) }
    }
}
#endif // SDK_V10
// swiftlint:enable missing_docs
