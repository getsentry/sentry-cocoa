@_implementationOnly import _SentryPrivate
import Foundation

extension Geo: Codable {
    private enum CodingKeys: String, CodingKey {
        case city
        case countryCode = "country_code"
        case region
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.city, forKey: .city)
        try container.encodeIfPresent(self.countryCode, forKey: .countryCode)
        try container.encodeIfPresent(self.region, forKey: .region)
    }
    
    @objc func serializeToDict() -> [String: Any] {
        return addsPerformanceOverhead_serializeToJSONObject(self)
    }
}
