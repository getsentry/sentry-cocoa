import Foundation
import UniformTypeIdentifiers

/// Warning codes for network body capture issues.
///
/// Raw values must match the frontend constants so the Sentry UI renders the correct warnings.
/// - SeeAlso: https://github.com/getsentry/sentry/blob/8b79857b2eff86f4df2f3abaf1e46c74893e3781/static/app/utils/replays/replay.tsx#L5
enum NetworkBodyWarning: String {
    case jsonTruncated = "MAYBE_JSON_TRUNCATED"
    case textTruncated = "TEXT_TRUNCATED"
    case bodyParseError = "BODY_PARSE_ERROR"
}

/// Main container for network request/response tracking.
///
/// ObjC callers (SentryNetworkTracker) create this object and populate it
/// via `setRequest`/`setResponse`. Swift callers (SentrySRDefaultBreadcrumbConverter)
/// consume it via `serialize()`.
@objc
@_spi(Private) public class SentryReplayNetworkDetails: NSObject {

    // MARK: - Nested Types (Swift-only)

    /// Typed representation of captured body content.
    enum BodyContent {
        /// Parsed JSON body (dictionary or array).
        case json(Any)
        /// Text body (plain text, HTML, XML, etc.).
        case text(String)

        init(_ value: Any) {
            if let string = value as? String {
                self = .text(string)
            } else {
                self = .json(value)
            }
        }

        var serializedValue: Any {
            switch self {
            case .json(let value): return value
            case .text(let string): return string
            }
        }
    }

    /// Captured request or response body with optional parsing warnings.
    struct Body {
        let content: BodyContent
        let warnings: [NetworkBodyWarning]

        init(content: Any, warnings: [NetworkBodyWarning] = []) {
            self.content = BodyContent(content)
            self.warnings = warnings
        }

        /// Parses raw body data based on content type.
        ///
        /// Returns nil if data is empty. Truncates to `maxBodySize` and adds
        /// appropriate warnings. Supports JSON, form-urlencoded, and text.
        init?(data: Data, contentType: String?) {
            guard !data.isEmpty else { return nil }

            let limit = SentryReplayNetworkDetails.maxBodySize
            let isTruncated = data.count > limit
            let slice = data.prefix(limit)

            var warnings = [NetworkBodyWarning]()
            // Strip MIME parameters (e.g. "; charset=utf-8") — UTType doesn't handle them.
            let mimeType = contentType.flatMap {
                $0.split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
            }
            let utType = mimeType.flatMap { UTType(mimeType: $0) }

            if mimeType == "application/x-www-form-urlencoded" {
                if isTruncated { warnings.append(.textTruncated) }
                self = Body.parseFormEncoded(slice, warnings: &warnings)
            } else if let utType, utType.conforms(to: .json) {
                if isTruncated { warnings.append(.jsonTruncated) }
                self = Body.parseJSON(slice, warnings: &warnings)
            } else if utType?.conforms(to: .text) == true {
                if isTruncated { warnings.append(.textTruncated) }
                self = Body.parseText(slice, warnings: &warnings)
            } else {
                // UTType is nil (unknown MIME type) or not text —
                // don't attempt to decode; use a placeholder description instead.
                let description = "[Body not captured: contentType=\(contentType ?? "unknown") (\(data.count) bytes)]"
                self = Body(content: description)
            }
        }

        // MARK: - Private Parsing

        private static func parseJSON(_ data: Data, warnings: inout [NetworkBodyWarning]) -> Body {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
                return Body(content: json, warnings: warnings)
            } catch {
                warnings.append(.bodyParseError)
                return parseText(data, warnings: &warnings)
            }
        }

        private static func parseFormEncoded(_ data: Data, warnings: inout [NetworkBodyWarning]) -> Body {
            guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
                  let components = URLComponents(string: "http://x?" + string),
                  let items = components.queryItems else {
                warnings.append(.bodyParseError)
                return parseText(data, warnings: &warnings)
            }

            var formData = [String: String]()
            for item in items where item.name.isEmpty == false {
                formData[item.name] = item.value ?? ""
            }
            return Body(content: formData, warnings: warnings)
        }

        private static func parseText(_ data: Data, warnings: inout [NetworkBodyWarning]) -> Body {
            if let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                return Body(content: string, warnings: warnings)
            }
            warnings.append(.bodyParseError)
            return Body(content: "", warnings: warnings)
        }

        func serialize() -> [String: Any] {
            var result = [String: Any]()
            result["body"] = content.serializedValue
            if !warnings.isEmpty {
                result["warnings"] = warnings.map(\.rawValue)
            }
            return result
        }
    }

    /// Captured HTTP request or response details (size, body, headers).
    struct Detail {
        let size: NSNumber?
        let body: Body?
        let headers: [String: String]

        func serialize() -> [String: Any] {
            var result = [String: Any]()
            if let size { result["size"] = size }
            if let body { result["body"] = body.serialize() }
            if !headers.isEmpty { result["headers"] = headers }
            return result
        }
    }

    // MARK: - Constants

    /// Maximum body size in bytes before truncation (150KB).
    static let maxBodySize = 150 * 1_024

    /// Key used to store network details in breadcrumb data dictionary.
    @objc public static let replayNetworkDetailsKey = "_networkDetails"

    // MARK: - Properties

    private(set) var method: String?
    private(set) var statusCode: NSNumber?
    private(set) var request: Detail?
    private(set) var response: Detail?

    /// Request body size in bytes, derived from request details.
    var requestBodySize: NSNumber? { request?.size }

    /// Response body size in bytes, derived from response details.
    var responseBodySize: NSNumber? { response?.size }

    // MARK: - Initialization

    /// Creates a new instance with the given HTTP method.
    @objc
    public init(method: String?) {
        self.method = method
        super.init()
    }

    // MARK: - ObjC Setters

    /// Sets request details from raw components.
    ///
    /// - Parameters:
    ///   - size: Request body size in bytes, or nil if unknown.
    ///   - body: Pre-parsed body content (dictionary, array, or string), or nil if not captured.
    ///   - headers: Filtered HTTP request headers.
    @objc
    public func setRequest(size: NSNumber?, body: Any?, headers: [String: String]) {
        self.request = Detail(
            size: size,
            body: body.map { Body(content: $0) },
            headers: headers
        )
    }

    /// Sets response details from raw components.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code.
    ///   - size: Response body size in bytes, or nil if unknown.
    ///   - body: Pre-parsed body content (dictionary, array, or string), or nil if not captured.
    ///   - headers: Filtered HTTP response headers.
    @objc
    public func setResponse(statusCode: Int, size: NSNumber?, body: Any?, headers: [String: String]) {
        self.statusCode = NSNumber(value: statusCode)
        self.response = Detail(
            size: size,
            body: body.map { Body(content: $0) },
            headers: headers
        )
    }

    // MARK: - Serialization

    /// Serializes to dictionary for inclusion in breadcrumb data.
    public func serialize() -> [String: Any] {
        var result = [String: Any]()
        if let method { result["method"] = method }
        if let statusCode { result["statusCode"] = statusCode }
        if let requestBodySize { result["requestBodySize"] = requestBodySize }
        if let responseBodySize { result["responseBodySize"] = responseBodySize }
        if let request { result["request"] = request.serialize() }
        if let response { result["response"] = response.serialize() }
        return result
    }

    public override var description: String {
        "SentryReplayNetworkDetails: \(serialize())"
    }
}
