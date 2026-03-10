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

            if mimeType == "application/x-www-form-urlencoded" {
                if isTruncated { warnings.append(.textTruncated) }
                self = Body.parseFormEncoded(slice, warnings: &warnings)
            } else if #available(macOS 11, *), let parsed = Body.parseByMimeType(mimeType, data: slice, isTruncated: isTruncated, warnings: &warnings) {
                self = parsed
            } else {
                let description = "[Body not captured: contentType=\(contentType ?? "unknown") (\(data.count) bytes)]"
                self = Body(content: description)
            }
        }

        // MARK: - Private Parsing

        /// Uses UTType to detect JSON/text content types. Returns nil for
        /// unrecognized types so the caller can fall through to a placeholder.
        /// UTType requires macOS 11+;  so this will not compile there.
        @available(macOS 11, *)
        private static func parseByMimeType(_ mimeType: String?, data: Data, isTruncated: Bool, warnings: inout [NetworkBodyWarning]) -> Body? {
            let utType = mimeType.flatMap { UTType(mimeType: $0) }
            if let utType, utType.conforms(to: .json) {
                if isTruncated { warnings.append(.jsonTruncated) }
                return parseJSON(data, warnings: &warnings)
            } else if utType?.conforms(to: .text) == true {
                if isTruncated { warnings.append(.textTruncated) }
                return parseText(data, warnings: &warnings)
            }
            return nil
        }

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

    /// Sets request details from raw body data.
    ///
    /// Parses the body data based on content type (JSON, form-urlencoded, text)
    /// and applies size limits and truncation warnings automatically.
    ///
    /// - Parameters:
    ///   - size: Request body size in bytes, or nil if unknown.
    ///   - bodyData: Raw body bytes, or nil if body capture is disabled or unavailable.
    ///   - contentType: MIME content type for body parsing (e.g. "application/json").
    ///   - allHeaders: All headers from the request (e.g. from `NSURLRequest.allHTTPHeaderFields`).
    ///   - configuredHeaders: Header names to extract, matched case-insensitively.
    @objc
    public func setRequest(size: NSNumber?, bodyData: Data?, contentType: String?, allHeaders: [String: Any]?, configuredHeaders: [String]?) {
        self.request = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: SentryReplayNetworkDetails.extractHeaders(from: allHeaders, matching: configuredHeaders)
        )
    }

    /// Sets response details from raw body data.
    ///
    /// Parses the body data based on content type (JSON, form-urlencoded, text)
    /// and applies size limits and truncation warnings automatically.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code.
    ///   - size: Response body size in bytes, or nil if unknown.
    ///   - bodyData: Raw body bytes, or nil if body capture is disabled or unavailable.
    ///   - contentType: MIME content type for body parsing (e.g. "application/json").
    ///   - allHeaders: All headers from the response (e.g. from `NSHTTPURLResponse.allHeaderFields`).
    ///   - configuredHeaders: Header names to extract, matched case-insensitively.
    @objc
    public func setResponse(statusCode: Int, size: NSNumber?, bodyData: Data?, contentType: String?, allHeaders: [String: Any]?, configuredHeaders: [String]?) {
        self.statusCode = NSNumber(value: statusCode)
        self.response = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: SentryReplayNetworkDetails.extractHeaders(from: allHeaders, matching: configuredHeaders)
        )
    }

    // MARK: - Header Extraction

    /// Extracts headers from a source dictionary using case-insensitive matching.
    /// Preserves the original casing of the header key as seen in the source.
    ///
    /// - Parameters:
    ///   - sourceHeaders: All available headers (e.g. from `NSURLRequest` or `NSHTTPURLResponse`).
    ///   - configuredHeaders: Header names to extract, matched case-insensitively.
    /// - Returns: Dictionary containing matched headers with original key casing preserved.
    static func extractHeaders(from sourceHeaders: [String: Any]?, matching configuredHeaders: [String]?) -> [String: String] {
        guard let sourceHeaders, let configuredHeaders else { return [:] }

        var extracted = [String: String]()
        for configured in configuredHeaders {
            let lowered = configured.lowercased()
            for (key, value) in sourceHeaders {
                if key.lowercased() == lowered {
                    extracted[key] = (value as? String) ?? "\(value)"
                    break
                }
            }
        }
        return extracted
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
