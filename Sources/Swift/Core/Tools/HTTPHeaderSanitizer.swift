// swiftlint:disable missing_docs
import Foundation

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
// swiftlint:enable missing_docs
