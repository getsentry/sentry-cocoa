@_implementationOnly import _SentryPrivate
import Foundation

private enum Error: Swift.Error {
    case jsonConversionError
}

enum SentryURLRequestFactory {
    
    private static let serverVersionString = "7"
    private static let requestTimeout: TimeInterval = 15
    
    static func envelopeRequest(with dsn: SentryDsn, data: Data) throws -> URLRequest {
        let apiURL = dsn.getEnvelopeEndpoint()
        let authHeader = Self.newAuthHeader(url: dsn.url)
        
        return try Self.envelopeRequest(with: apiURL, data: data, authHeader: authHeader)
    }
    
    static func envelopeRequest(with url: URL, data: Data, authHeader: String?) throws -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.requestTimeout)
        
        request.httpMethod = "POST"
        
        if let authHeader = authHeader {
            request.setValue(authHeader, forHTTPHeaderField: "X-Sentry-Auth")
        }
        request.setValue("application/x-sentry-envelope", forHTTPHeaderField: "Content-Type")
        request.setValue("\(SentryMeta.sdkName)/\(SentryMeta.versionString)", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        
        var error: NSError?
        let data = sentry_gzippedWithCompressionLevel(data, -1, &error)
        if let error {
            SentryLog.log(message: "Failed to compress envelope request body: \(error)", andLevel: .error)
            throw error
        }
        request.httpBody = data
        
        SentryLog.log(message: "Constructed request: \(self)", andLevel: .debug)
        return request
    }
    
    private static func newHeaderPart(key: String, value: Any) -> String {
        return "\(key)=\(value)"
    }
    
    private static func newAuthHeader(url: URL) -> String {
        var string = "Sentry "
        string += newHeaderPart(key: "sentry_version", value: serverVersionString) + ","
        string += newHeaderPart(key: "sentry_client", value: "\(SentryMeta.sdkName)/\(SentryMeta.versionString)") + ","
        string += newHeaderPart(key: "sentry_key", value: url.user ?? "")
        
        if let password = url.password {
            string += "," + newHeaderPart(key: "sentry_secret", value: password)
        }
        
        return string
    }
}
