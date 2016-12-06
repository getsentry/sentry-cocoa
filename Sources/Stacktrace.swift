//
//  Stacktrace.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/22/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.stacktrace.Stacktrace`
@objc public final class Stacktrace: NSObject {
    public let frames: [Frame]
    
    internal convenience init?(appleCrashTreadBacktraceDict: [String: AnyObject]?, binaryImages: [BinaryImage]?) {
        
        guard let appleCrashTreadBacktraceDict = appleCrashTreadBacktraceDict, let binaryImages = binaryImages else {
            return nil
        }
        
        let frames = (appleCrashTreadBacktraceDict["contents"] as? [[String: AnyObject]])?
            .flatMap({ Frame(appleCrashFrameDict: $0, binaryImages: binaryImages) })
        self.init(frames: frames)
        
    }
    
    @objc public init(frames: [Frame]?) {
        self.frames = frames ?? []
    }
    
}

extension Stacktrace: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        #if swift(>=3.0)
        return [:]
            .set("frames", value: frames.reversed().map({ $0.serialized }))
        #else
        return [:]
            .set("frames", value: frames.reverse().map({ $0.serialized }))
        #endif
    }
}

@objc public class Frame: NSObject {
    public var file: String?
    public var function: String?
    public var module: String?
    
    public var line: Int?
    
    public var package: String?
    public var imageAddress: String?
    public var platform: String?
    public var instructionAddress: String?
    public var symbolAddress: String?
    
    var fileName: String? {
        guard let file = file else { return nil }
        return (file as NSString).lastPathComponent
    }
    
    var culprit: String? {
        guard let fileName = fileName, let line = line, let function = function else { return nil }
        return "\(fileName):\(line) \(function)"
    }
    
    /// Creates `Exception` object
    @objc public init(file: String? = nil, function: String? = nil, module: String? = nil, line: Int) {
        self.file = file
        self.function = function
        self.module = module
        
        self.line = line
        
        super.init()
    }
    
    private override init() {
        super.init()
    }
    
    internal convenience init?(appleCrashFrameDict frameDict: [String: AnyObject], binaryImages: [BinaryImage]) {
        
        if let instructionAddress = BinaryImage.asMemoryAddress(frameDict["instruction_addr"]),
            let binaryImage = BinaryImage.getBinaryImage(binaryImages, address: instructionAddress) {
            
            self.init()
            
            self.function = frameDict["symbol_name"] as? String
            self.package = binaryImage.name
            
            self.imageAddress = BinaryImage.getHexAddress(binaryImage.imageAddress)
            self.instructionAddress = BinaryImage.getHexAddress(frameDict["instruction_addr"])
            self.symbolAddress = BinaryImage.getHexAddress(frameDict["symbol_addr"])
        } else {
            return nil
        }
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
        attributes.append(("package", package))
        attributes.append(("image_addr", imageAddress))
        attributes.append(("instruction_addr", instructionAddress))
        attributes.append(("symbol_addr", symbolAddress))
        
        return convertAttributes(attributes)
    }
}
