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
///
/// - Important: Request and response parsing happens before publishing the result to internal
///   state. The short state updates and snapshots are synchronized for consistent replay data.
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
        private static let filteredValue = "[Filtered]"

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
            } else if let parsed = Body.parseByMimeType(mimeType, data: slice, encoding: encoding, isTruncated: isTruncated, warnings: &warnings) {
                self = parsed
            } else {
#if SDK_V10
                self = Body(content: Body.filteredValue)
#else
                let description = "[Body not captured: contentType=\(contentType ?? "unknown") (\(data.count) bytes)]"
                self = Body(content: description)
#endif // SDK_V10
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
#if SDK_V10
                return Body(content: filteredValue, warnings: warnings)
#else
                return parseText(data, encoding: encoding, warnings: &warnings)
#endif // SDK_V10
            }
            return nil
        }

        private static func parseJSON(_ data: Data, encoding: String.Encoding = .utf8, warnings: inout [NetworkBodyWarning]) -> Body {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
#if SDK_V10
                guard let values = json as? [String: Any] else {
                    return Body(content: filteredValue, warnings: warnings)
                }
                return Body(
                    content: SentryDataCollection.KeyValueFilter.filterSensitiveValues(values),
                    warnings: warnings
                )
#else
                return Body(content: json, warnings: warnings)
#endif // SDK_V10
            } catch {
                warnings.append(.bodyParseError)
#if SDK_V10
                return Body(content: filteredValue, warnings: warnings)
#else
                return parseText(data, encoding: encoding, warnings: &warnings)
#endif // SDK_V10
            }
        }

        /// Parses `application/x-www-form-urlencoded` data into a dictionary.
        private static func parseFormEncoded(_ data: Data, encoding: String.Encoding, warnings: inout [NetworkBodyWarning]) -> Body {
            guard let urlEncodedFormData = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
                warnings.append(.bodyParseError)
#if SDK_V10
                return Body(content: filteredValue, warnings: warnings)
#else
                return parseText(data, encoding: encoding, warnings: &warnings)
#endif // SDK_V10
            }

            var formData = [String: Any]()
            for rawElement in urlEncodedFormData.components(separatedBy: "&") where !rawElement.isEmpty {
                let comps = rawElement.components(separatedBy: "=")
                if comps.count < 2 {
                    warnings.append(.bodyParseError)
#if SDK_V10
                    return Body(content: filteredValue, warnings: warnings)
#else
                    return parseText(data, encoding: encoding, warnings: &warnings)
#endif // SDK_V10
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
#if SDK_V10
            return Body(
                content: SentryDataCollection.KeyValueFilter.filterSensitiveValues(formData),
                warnings: warnings
            )
#else
            return Body(content: formData, warnings: warnings)
#endif // SDK_V10
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
#if SDK_V10
        let cookies: [String: String]
#endif // SDK_V10

        func serialize() -> [String: Any] {
            var result = [String: Any]()
            result["size"] = size
            result["body"] = body?.serialize()
            if !headers.isEmpty { result["headers"] = headers }
#if SDK_V10
            if !cookies.isEmpty { result["cookies"] = cookies }
#endif // SDK_V10
            return result
        }
    }

    // MARK: - Constants

    /// Maximum body size in bytes before truncation.
    /// Mirrors `NETWORK_BODY_MAX_SIZE` from sentry-javascript's replay-internal:
    /// https://github.com/getsentry/sentry-javascript/blob/399cc859ce250ba5db3656685bd05794f571bee5/packages/replay-internal/src/constants.ts#L33
    static let maxBodySize = 150_000

    /// Key used to store network details in breadcrumb data dictionary.
    /// The __sentry key prefix strips this from event serialization.
    @objc public static let replayNetworkDetailsKey = "__sentry_networkDetails"

    // MARK: - Properties

    struct State {
        var statusCode: NSNumber?
        var request: Detail?
        var response: Detail?
    }

    let method: String?
    let state = SentryMutex(State())

    // MARK: - Initialization

    /// Creates a new instance with the given HTTP method.
    @objc
    public init(method: String?) {
        self.method = method
        super.init()
    }

    public override var description: String {
        "SentryReplayNetworkDetails: \(serialize())"
    }
}
