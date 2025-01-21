@_implementationOnly import _SentryPrivate
import Foundation

extension Frame: Decodable {

    enum CodingKeys: String, CodingKey {
        case symbolAddress = "symbol_addr"
        case fileName = "filename"
        case function
        case module
        case package
        case imageAddress = "image_addr"
        case platform
        case instructionAddress = "instruction_addr"
        case instruction
        case lineNumber = "lineno"
        case columnNumber = "colno"
        case inApp = "in_app"
        case stackStart = "stack_start"
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init()
        self.symbolAddress = try container.decodeIfPresent(String.self, forKey: .symbolAddress)
        self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        self.function = try container.decodeIfPresent(String.self, forKey: .function)
        self.module = try container.decodeIfPresent(String.self, forKey: .module)
        self.package = try container.decodeIfPresent(String.self, forKey: .package)
        self.imageAddress = try container.decodeIfPresent(String.self, forKey: .imageAddress)
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
        self.instructionAddress = try container.decodeIfPresent(String.self, forKey: .instructionAddress)
        self.instruction = try container.decode(UInt.self, forKey: .instruction)
        self.lineNumber = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .lineNumber))?.value
        self.columnNumber = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .columnNumber))?.value
        self.inApp = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .inApp))?.value
        self.stackStart = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .stackStart))?.value
    }
}
