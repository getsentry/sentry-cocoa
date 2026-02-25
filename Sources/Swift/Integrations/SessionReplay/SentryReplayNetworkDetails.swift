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
            let (mimeType, encoding) = Body.parseMimeAndEncoding(from: contentType)

            if mimeType == "application/x-www-form-urlencoded" {
                if isTruncated { warnings.append(.textTruncated) }
                self = Body.parseFormEncoded(slice, encoding: encoding, warnings: &warnings)
            } else if #available(macOS 11, *), let parsed = Body.parseByMimeType(mimeType, data: slice, encoding: encoding, isTruncated: isTruncated, warnings: &warnings) {
                self = parsed
            } else {
                let description = "[Body not captured: contentType=\(contentType ?? "unknown") (\(data.count) bytes)]"
                self = Body(content: description)
            }
        }

        // MARK: - Private Parsing

        /// Extracts MIME type and string encoding from a Content-Type header value.
        ///
        /// Returns `.utf8` when the charset parameter is missing or unrecognized.
        ///
        /// Examples:
        /// - `"application/json"` → `("application/json", .utf8)`
        /// - `"text/html; charset=iso-8859-1"` → `("text/html", .isoLatin1)`
        /// - `nil` → `(nil, .utf8)`
        static func parseMimeAndEncoding(from contentType: String?) -> (mimeType: String?, encoding: String.Encoding) {
            guard let contentType else { return (nil, .utf8) }

            let parts = contentType.split(separator: ";")
            let mimeType = parts.first.map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }

            var encoding: String.Encoding = .utf8
            for part in parts.dropFirst() {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                guard trimmed.lowercased().hasPrefix("charset=") else { continue }
                let charsetValue = String(trimmed.dropFirst("charset=".count))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                encoding = stringEncoding(fromCharset: charsetValue)
                break
            }
            return (mimeType, encoding)
        }

        /// Converts an IANA charset name to a `String.Encoding`.
        ///
        /// Returns `.utf8` for unrecognized or empty charset names.
        private static func stringEncoding(fromCharset charset: String) -> String.Encoding {
            guard !charset.isEmpty else { return .utf8 }
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
            guard cfEncoding != kCFStringEncodingInvalidId else { return .utf8 }
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }

        /// Uses UTType to detect JSON/text content types. Returns nil for
        /// unrecognized types so the caller can fall through to a placeholder.
        /// UTType requires macOS 11+;  so this will not compile there.
        @available(macOS 11, *)
        private static func parseByMimeType(_ mimeType: String?, data: Data, encoding: String.Encoding, isTruncated: Bool, warnings: inout [NetworkBodyWarning]) -> Body? {
            guard let utType = mimeType.flatMap({ UTType(mimeType: $0) }) else {
                return nil
            }
            if utType.conforms(to: .json) {
                if isTruncated { warnings.append(.jsonTruncated) }
                return parseJSON(data, encoding: encoding, warnings: &warnings)
            }
            if utType.conforms(to: .text) {
                if isTruncated { warnings.append(.textTruncated) }
                return parseText(data, encoding: encoding, warnings: &warnings)
            }
            return nil
        }

        private static func parseJSON(_ data: Data, encoding: String.Encoding = .utf8, warnings: inout [NetworkBodyWarning]) -> Body {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
                return Body(content: json, warnings: warnings)
            } catch {
                warnings.append(.bodyParseError)
                return parseText(data, encoding: encoding, warnings: &warnings)
            }
        }

        /// Parses `application/x-www-form-urlencoded` data into a dictionary.
        private static func parseFormEncoded(_ data: Data, encoding: String.Encoding, warnings: inout [NetworkBodyWarning]) -> Body {
            guard let urlEncodedFormData = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
                warnings.append(.bodyParseError)
                return parseText(data, encoding: encoding, warnings: &warnings)
            }

            var formData = [String: Any]()
            for rawElement in urlEncodedFormData.components(separatedBy: "&") where !rawElement.isEmpty {
                let comps = rawElement.components(separatedBy: "=")
                if comps.count < 2 {
                    warnings.append(.bodyParseError)
                    return parseText(data, encoding: encoding, warnings: &warnings)
                }
                let key = decodeFormComponent(comps[0])
                let value = decodeFormComponent(comps.dropFirst().joined(separator: "="))
                guard !key.isEmpty else { continue }
                if let existing = formData[key] {
                    if var list = existing as? [String] {
                        list.append(value)
                        formData[key] = list
                    } else if let text = existing as? String {
                        formData[key] = [text, value]
                    }
                } else {
                    formData[key] = value
                }
            }
            return Body(content: formData, warnings: warnings)
        }

        /// Decodes a form-urlencoded component: converts `+` to space and removes percent-encoding.
        /// Falls back to the `+`-to-space result if percent-decoding fails (e.g. `%ZZ`).
        private static func decodeFormComponent(_ component: String) -> String {
            let plusDecoded = component.replacingOccurrences(of: "+", with: " ")
            return plusDecoded.removingPercentEncoding ?? plusDecoded
        }

        private static func parseText(_ data: Data, encoding: String.Encoding = .utf8, warnings: inout [NetworkBodyWarning]) -> Body {
            // Truncation at a multi-byte boundary (e.g. UTF-8 CJK, emoji) makes
            // String(data:encoding:) return nil. Try dropping up to 3 trailing bytes
            // to find a valid boundary before giving up.
            for drop in 0...min(3, data.count) {
                let slice = drop == 0 ? data : data.dropLast(drop)
                if let string = String(data: slice, encoding: encoding) ?? String(data: slice, encoding: .utf8) {
                    return Body(content: string, warnings: warnings)
                }
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

    /// Maximum body size in bytes before truncation.
    /// Mirrors `NETWORK_BODY_MAX_SIZE` from sentry-javascript's replay-internal:
    /// https://github.com/getsentry/sentry-javascript/blob/399cc859ce250ba5db3656685bd05794f571bee5/packages/replay-internal/src/constants.ts#L33
    static let maxBodySize = 150_000

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
