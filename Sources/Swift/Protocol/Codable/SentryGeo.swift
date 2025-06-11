import Foundation

/// Approximate geographical location of the end user or device.
///
/// Example of serialized data:
/// {
///   "geo": {
///     "country_code": "US",
///     "city": "Ashburn",
///     "region": "San Francisco"
///   }
/// }
@objc(SentryGeo)
@objcMembers
open class Geo: NSObject, NSCopying, Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case city
        case countryCode = "country_code"
        case region
    }
    
    /// Optional: Human readable city name.
    open var city: String?
    
    /// Optional: Two-letter country code (ISO 3166-1 alpha-2).
    open var countryCode: String?
    
    /// Optional: Human readable region name or code.
    open var region: String?
    
    required public init(from decoder: Decoder) throws {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
    }
    
    required public override init() {
        super.init()
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Geo()
        copy.city = self.city
        copy.countryCode = self.countryCode
        copy.region = self.region
        return copy
    }
    
    public func serialize() -> [String: Any] {
        var serializedData = [String: Any]()
        
        if let city = self.city {
            serializedData["city"] = city
        }
        
        if let countryCode = self.countryCode {
            serializedData["country_code"] = countryCode
        }
        
        if let region = self.region {
            serializedData["region"] = region
        }
        
        return serializedData
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Geo else {
            return false
        }
        
        return isEqualToGeo(other)
    }
    
    public func isEqualToGeo(_ geo: Geo) -> Bool {
        if self === geo {
            return true
        }
        
        return self.city == geo.city &&
            self.countryCode == geo.countryCode &&
            self.region == geo.region
    }
    
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(city)
        hasher.combine(countryCode)
        hasher.combine(region)
        return hasher.finalize()
    }
} 

extension Geo: SentrySerializable { }
