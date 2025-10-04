@_implementationOnly import _SentryPrivate
import Foundation

final class UserDecodable: User {
    @available(*, deprecated)
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}

extension UserDecodable: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case email
        case username
        case ipAddress = "ip_address"
        case segment
        case name
        case geo
        case data
    }

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.geo = try container.decodeIfPresent(GeoDecodable.self, forKey: .geo)
        
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .data)
        }
    }
}
