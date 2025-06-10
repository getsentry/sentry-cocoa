import Foundation

/// Sentry representation of an NSError to send to Sentry.
@objcMembers
open class SentryNSError: NSObject, SentrySerializable, Decodable {
    
    /// The domain of an NSError.
    open var domain: String
    
    /// The error code of an NSError.
    open var code: Int
    
    /// Initializes SentryNSError and sets the domain and code.
    /// - Parameters:
    ///   - domain: The domain of an NSError.
    ///   - code: The error code of an NSError.
    public init(domain: String, code: Int) {
        self.domain = domain
        self.code = code
        super.init()
    }
    
    open func serialize() -> [String: Any] {
        return ["domain": domain, "code": code]
    }

    enum CodingKeys: String, CodingKey {
        case domain
        case code
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let domain = try container.decode(String.self, forKey: .domain)
        let code = try container.decode(Int.self, forKey: .code)
        self.init(domain: domain, code: code)
    }
}
