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
@objcMembers
@objc(SentryGeo)
public class Geo: NSObject, SentrySerializable, NSCopying, Codable {
    
    /// Optional: Human readable city name.
    public var city: String?
    
    /// Optional: Two-letter country code (ISO 3166-1 alpha-2).
    public var countryCode: String?
    
    /// Optional: Human readable region name or code.
    public var region: String?
    
    public func serialize() -> [String: Any] {
        
        do {
               
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            
            let jsonData = try encoder.encode(self)
            
           if let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String: Any] {
               return dictionary
           }
           } catch {
               print("Error encoding object to dictionary: \(error)")
           }
        
        return [:]
    }
    
    public override func isEqual(_ other: Any?) -> Bool {
        guard let otherGeo = other as? Geo else { return false }
        return isEqual(to: otherGeo)
    }
    
    @objc(isEqualToGeo:)
    public func isEqual(to geo: Geo) -> Bool {
        return city == geo.city &&
               countryCode == geo.countryCode &&
               region == geo.region
    }
    
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(city)
        hasher.combine(countryCode)
        hasher.combine(region)
        return hasher.finalize()
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Geo()
        copy.city = city
        copy.countryCode = countryCode
        copy.region = region
        return copy
    }
}
