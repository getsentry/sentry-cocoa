@_implementationOnly import _SentryPrivate
import Foundation

final class MechanismContextDecodable: MechanismContext {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}

extension MechanismContextDecodable: Decodable {

    enum CodingKeys: String, CodingKey {
        case signal
        case machException = "mach_exception"
        case error = "ns_error"
    }

    private convenience init(decodedFrom decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.signal = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .signal)
        }
        self.machException = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .machException)
        }
        self.error = try container.decodeIfPresent(SentryNSErrorDecodable.self, forKey: .error)
    }
}
