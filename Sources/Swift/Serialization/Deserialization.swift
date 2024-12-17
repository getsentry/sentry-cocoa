import Foundation

@objcMembers
class SentryDeserialization: NSObject {
    
    static func deserializeSentryGeo(json: [String: Any]) -> Geo {
        let geo = Geo()
        geo.city = json["city"] as? String
        geo.countryCode = json["country_code"] as? String
        geo.region = json["region"] as? String
        return geo
    }
}
