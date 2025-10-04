@_implementationOnly import _SentryPrivate
import Foundation

final class GeoDecodable: Geo {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}

extension GeoDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case city
        case countryCode = "country_code"
        case region
    }

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
    }
}
