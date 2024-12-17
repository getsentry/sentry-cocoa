import Foundation

@objcMembers
class SentryGeoDesializer: NSObject {
    
    static func serialize(geo: Geo) -> [String: Any] {
        var json = [String: Any]()
        json["city"] = geo.city
        if let countryCode = geo.countryCode {
            json["country_code"] = countryCode
        }
        
        if let region = geo.region {
            json["region"] = region
        }
        
        return json
    }
    
    static func deserialize(json: [String: Any]) -> Geo {
        let geo = Geo()
        geo.city = json["city"] as? String
        geo.countryCode = json["country_code"] as? String
        geo.region = json["region"] as? String
        return geo
    }
}
