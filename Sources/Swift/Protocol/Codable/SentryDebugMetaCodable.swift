@_implementationOnly import _SentryPrivate
import Foundation

final class DebugMetaDecodable: DebugMeta {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}

// Here only to satisfy the cocoapods compiler, which throws an
// error about SentrySerializable not being found if we don't extend
// an ObjC class here.
#if COCOAPODS
extension DebugMeta { }
#endif

extension DebugMetaDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case debugID = "debug_id"
        case type
        case imageSize = "image_size"
        case imageAddress = "image_addr"
        case imageVmAddress = "image_vmaddr"
        case codeFile = "code_file"
    }

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()

        self.debugID = try container.decodeIfPresent(String.self, forKey: .debugID)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.imageSize = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .imageSize))?.value
        self.imageAddress = try container.decodeIfPresent(String.self, forKey: .imageAddress)
        self.imageVmAddress = try container.decodeIfPresent(String.self, forKey: .imageVmAddress)
        self.codeFile = try container.decodeIfPresent(String.self, forKey: .codeFile)
    
    }
}
