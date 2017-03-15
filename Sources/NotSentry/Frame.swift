//
//  Frame.swift
//  Sentry
//
//  Created by Daniel Griesser on 07/12/2016.
//
//

import Foundation

@objc(SentryFrame) public class Frame: NSObject {
    public var fileName: String?
    public var function: String?
    public var module: String?
    
    public var line: Int?
    public var column: Int?
    
    public var package: String?
    public var imageAddress: String?
    public var platform: String?
    public var instructionAddress: String?
    public var symbolAddress: String?
    
    var culprit: String? {
        guard let fileName = fileName, let line = line, let function = function else { return nil }
        return "\(fileName):\(line) \(function)"
    }
    
    /// Creates `Exception` object
    @objc public init(fileName: String? = nil, function: String? = nil, module: String? = nil, line: Int) {
        self.fileName = fileName
        self.function = function
        self.module = module
        self.line = line
        super.init()
    }
    
    @objc public convenience init(fileName: String? = nil, function: String? = nil, module: String? = nil, line: Int, column: Int) {
        self.init(fileName: fileName, function: function, module: module, line: line)
        self.column = column
    }
    
    private override init() {
        super.init()
    }
    
    internal convenience init?(appleCrashFrameDict frameDict: [String: AnyObject], binaryImages: [BinaryImage]) {
        guard let instructionAddress = MemoryAddress(frameDict["instruction_addr"]),
            let binaryImage = BinaryImage.getBinaryImage(binaryImages, address: instructionAddress) else {
                return nil
        }
        
        self.init()
        
        self.function = frameDict["symbol_name"] as? String
        self.package = binaryImage.name
        self.imageAddress = binaryImage.imageAddress?.asHex()
        self.instructionAddress = MemoryAddress(frameDict["instruction_addr"])?.asHex()
        self.symbolAddress = MemoryAddress(frameDict["symbol_addr"])?.asHex()
    }
    
}

extension Frame: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    
    internal var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("filename", fileName))
        attributes.append(("function", function))
        attributes.append(("module", module))
        attributes.append(("lineno", line))
        attributes.append(("colno", column))
        attributes.append(("package", package))
        attributes.append(("image_addr", imageAddress))
        attributes.append(("instruction_addr", instructionAddress))
        attributes.append(("symbol_addr", symbolAddress))
        attributes.append(("platform", platform))
        
        return convertAttributes(attributes)
    }
}
