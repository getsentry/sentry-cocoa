@_implementationOnly import _SentryPrivate
import Foundation

#if SDK_V9
final class GeoDecodable: Geo {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias GeoDecodable = Geo
#endif
extension GeoDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case city
        case countryCode = "country_code"
        case region
    }
    
    #if !SDK_V9
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
    }
}
