import Foundation

/// Warning codes for network body capture issues.
enum NetworkBodyWarning: String {
    case jsonTruncated = "JSON_TRUNCATED"
    case textTruncated = "TEXT_TRUNCATED"
    case invalidJson = "INVALID_JSON"
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
            if !headers.isEmpty {
                result["headers"] = headers
            }
            return result
        }
    }

    // MARK: - Properties

    /// Key used to store network details in breadcrumb data dictionary.
    @objc public static let replayNetworkDetailsKey = "_networkDetails"

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
