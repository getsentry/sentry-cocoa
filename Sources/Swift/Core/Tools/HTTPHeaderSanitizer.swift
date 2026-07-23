// swiftlint:disable missing_docs
import Foundation

#if SDK_V10
enum HTTPHeaderSanitizer {

    // MARK: - Types

    struct SanitizedHeaders {
        let headers: [String: String]
        let cookies: [String: String]
    }

    private enum CookieHeader: String {
        case cookie
        case setCookie = "set-cookie"
    }

    // MARK: - Constants

    private static let sensitiveDataSubstitute = "[Filtered]"

    // MARK: - Methods

    static func sanitizeRequestHeaders(
        _ headers: [String: String],
        options: SentryDataCollection.Options
    ) -> SanitizedHeaders {
        sanitizeHeaders(
            headers,
            headerBehavior: options.httpHeaders.request,
            cookieBehavior: options.cookies
        )
    }

    static func sanitizeResponseHeaders(
        _ headers: [String: String],
        options: SentryDataCollection.Options
    ) -> SanitizedHeaders {
        sanitizeHeaders(
            headers,
            headerBehavior: options.httpHeaders.response,
            cookieBehavior: options.cookies
        )
    }

    private static func sanitizeHeaders(
        _ headers: [String: String],
        headerBehavior: SentryDataCollection.KeyValueCollectionBehavior,
        cookieBehavior: SentryDataCollection.KeyValueCollectionBehavior
    ) -> SanitizedHeaders {
        var regularHeaders: [String: String] = [:]
        var cookies: [String: String] = [:]

        for (name, value) in headers {
            guard let cookieHeader = CookieHeader(rawValue: name.lowercased()) else {
                regularHeaders[name] = value
                continue
            }

            collectCookies(
                from: value,
                cookieHeader: cookieHeader,
                name: name,
                headerBehavior: headerBehavior,
                cookieBehavior: cookieBehavior,
                regularHeaders: &regularHeaders,
                cookies: &cookies
            )
        }

        return SanitizedHeaders(
            headers: SentryDataCollection.KeyValueFilter.filter(
                regularHeaders,
                behavior: headerBehavior
            ),
            cookies: cookies
        )
    }

    private static func collectCookies(
        from headerValue: String,
        cookieHeader: CookieHeader,
        name: String,
        headerBehavior: SentryDataCollection.KeyValueCollectionBehavior,
        cookieBehavior: SentryDataCollection.KeyValueCollectionBehavior,
        regularHeaders: inout [String: String],
        cookies: inout [String: String]
    ) {
        guard cookieBehavior != .off else {
            return
        }

        guard let parsedCookies = parseCookies(headerValue, cookieHeader: cookieHeader) else {
            if headerBehavior != .off {
                regularHeaders[name] = Self.sensitiveDataSubstitute
            }
            return
        }

        cookies.merge(
            SentryDataCollection.KeyValueFilter.filter(parsedCookies, behavior: cookieBehavior),
            uniquingKeysWith: { _, incoming in incoming }
        )
    }

    private static func parseCookies(
        _ headerValue: String,
        cookieHeader: CookieHeader
    ) -> [String: String]? {
        let cookieValues: [Substring]
        switch cookieHeader {
        case .cookie:
            cookieValues = headerValue.split(separator: ";")
        case .setCookie:
            guard let cookie = headerValue
                .split(separator: ";", maxSplits: 1)
                .first
            else {
                return nil
            }
            cookieValues = [cookie]
        }

        var result: [String: String] = [:]
        for value in cookieValues {
            let pair = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pair.isEmpty, let separatorIndex = pair.firstIndex(of: "=") else {
                return nil
            }

            let cookieName = pair[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cookieName.isEmpty else {
                return nil
            }

            let cookieValue = String(pair[pair.index(after: separatorIndex)...])
            result[cookieName] = cookieValue
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
