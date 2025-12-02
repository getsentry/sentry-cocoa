@_implementationOnly import _SentryPrivate
import Foundation

#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// Represents a Sentry Data Source Name (DSN) which identifies a Sentry project.
@objc(SentryDsn)
public final class SentryDsn: NSObject {
    
    // Error code constant - must match SentryError.h
    // Note: We use the numeric value directly since kSentryErrorInvalidDsnError
    // is not accessible from Swift (it's a C enum value)
    private static let kSentryErrorInvalidDsnError: Int = 100
    
    private static func createError(code: Int, description: String) -> NSError {
        // Use the Objective-C constant instead of hardcoding the string
        // SentryErrorDomain is accessible because it's in the public header
        return NSError(
            domain: SentryErrorDomain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
    
    /// The parsed URL from the DSN string.
    @objc public let url: URL
    
    private var _envelopeEndpoint: URL?
    private let lock = NSLock()
    
    /// Initializes a SentryDsn from a DSN string.
    /// - Parameters:
    ///   - dsnString: The DSN string to parse.
    ///   - error: An optional error pointer that will be set if the DSN is invalid.
    /// - Returns: A new SentryDsn instance, or nil if the DSN string is invalid.
    @objc
    public init?(string dsnString: String?, didFailWithError error: NSErrorPointer) {
        guard let parsedUrl = SentryDsn.convertDsnString(dsnString, didFailWithError: error) else {
            return nil
        }
        self.url = parsedUrl
        super.init()
    }
    
    /// Swift convenience initializer that throws instead of using NSErrorPointer.
    /// - Parameter string: The DSN string to parse.
    /// - Throws: An error if the DSN string is invalid.
    public convenience init(string: String?) throws {
        var error: NSError?
        guard let parsedUrl = SentryDsn.convertDsnString(string, didFailWithError: &error) else {
            throw error ?? SentryDsn.createError(code: SentryDsn.kSentryErrorInvalidDsnError, description: "Invalid DSN")
        }
        self.init(url: parsedUrl)
    }
    
    /// Internal initializer for use by the throwing convenience initializer.
    private init(url: URL) {
        self.url = url
        super.init()
    }
    
    /// Generates a SHA1 hash of the DSN URL.
    /// - Returns: A hexadecimal string representation of the hash.
    @objc
    public func getHash() -> String {
        let data: Data
        if let encodedData = url.absoluteString.data(using: .utf8) {
            data = encodedData
        } else {
            // This should never happen for a valid URL, but handle it defensively
            // to match Objective-C behavior (hash of empty data)
            assertionFailure("Failed to encode URL to UTF-8: \(url.absoluteString)")
            // Log the error for production builds
            #if DEBUG
            print("[Sentry] Warning: Failed to encode DSN URL to UTF-8, using empty data for hash")
            #endif
            data = Data()
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Returns the envelope endpoint URL for this DSN.
    /// - Returns: The envelope endpoint URL.
    @objc
    public func getEnvelopeEndpoint() -> URL {
        if let cached = _envelopeEndpoint {
            return cached
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = _envelopeEndpoint {
            return cached
        }
        
        let endpoint = getBaseEndpoint().appendingPathComponent("envelope/")
        _envelopeEndpoint = endpoint
        return endpoint
    }
    
    /// Returns the base API endpoint URL for this DSN.
    /// - Returns: The base endpoint URL.
    @objc
    public func getBaseEndpoint() -> URL {
        let projectId = url.lastPathComponent
        var paths = url.pathComponents
        
        // [0] = /
        // [1] = projectId
        // If there are more than two, that means someone wants to have an
        // additional path ref: https://github.com/getsentry/sentry-cocoa/issues/236
        var path = ""
        if paths.count > 2 {
            paths.removeFirst() // We remove the leading /
            paths.removeLast()  // We remove projectId since we add it later
            path = "/" + paths.joined(separator: "/") // We put together the path
        }
        
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = "\(path)/api/\(projectId)/"
        
        // This should always be valid since we already validated the URL
        return components.url ?? url
    }
    
    /// Converts a DSN string to a URL after validation.
    /// - Parameters:
    ///   - dsnString: The DSN string to convert.
    ///   - error: An optional error pointer that will be set if the DSN is invalid.
    /// - Returns: A valid URL, or nil if the DSN string is invalid.
    private static func convertDsnString(_ dsnString: String?, didFailWithError error: NSErrorPointer) -> URL? {
        guard let dsnString = dsnString else {
            setError(error, message: "DSN string is nil")
            return nil
        }
        
        let trimmedDsnString = dsnString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: trimmedDsnString) else {
            setError(error, message: "Invalid DSN URL")
            return nil
        }
        
        if let errorMessage = validateDsnURL(url) {
            setError(error, message: errorMessage)
            return nil
        }
        
        return url
    }
    
    /// Validates a DSN URL.
    /// - Parameter url: The URL to validate.
    /// - Returns: An error message if validation fails, or nil if valid.
    private static func validateDsnURL(_ url: URL) -> String? {
        let allowedSchemes: Set<String> = ["http", "https"]
        
        if url.scheme == nil {
            return "URL scheme of DSN is missing"
        }
        
        if let scheme = url.scheme, !allowedSchemes.contains(scheme) {
            return "Unrecognized URL scheme in DSN"
        }
        
        if url.host == nil || url.host?.isEmpty == true {
            return "Host component of DSN is missing"
        }
        
        if url.user == nil {
            return "User component of DSN is missing"
        }
        
        if url.pathComponents.count < 2 {
            return "Project ID path component of DSN is missing"
        }
        
        return nil
    }
    
    /// Sets an error pointer with a Sentry error.
    /// - Parameters:
    ///   - error: The error pointer to set.
    ///   - message: The error message.
    private static func setError(_ error: NSErrorPointer, message: String) {
        if let error = error {
            error.pointee = createError(code: SentryDsn.kSentryErrorInvalidDsnError, description: message)
        }
    }
}
