@_implementationOnly import _SentryPrivate
import Foundation

final class SentryStacktraceDecodable: SentryStacktrace {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}

extension SentryStacktraceDecodable: Decodable {

    enum CodingKeys: String, CodingKey {
        case frames
        case registers
        case snapshot
    }

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let frames = try container.decodeIfPresent([FrameDecodable].self, forKey: .frames) ?? []
        let registers = try container.decodeIfPresent([String: String].self, forKey: .registers) ?? [:]
        self.init(frames: frames, registers: registers)
        
        let snapshot = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .snapshot)
        self.snapshot = snapshot?.value
    }
}
