@_implementationOnly import _SentryPrivate
import Foundation

extension User: Decodable {
    
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
    
    @available(*, deprecated, message: "Segment is deprecated, but we still need decode it.")
    required convenience public init(from decoder: any Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        self.segment = try container.decodeIfPresent(String.self, forKey: .segment)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.geo = try container.decodeIfPresent(Geo.self, forKey: .geo)
        
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: SentryArbitraryData].self, forKey: .data)
        }
    }
}
