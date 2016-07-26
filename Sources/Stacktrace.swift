//
//  Stacktrace.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/22/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.stacktrace.Stacktrace`
@objc public class Stacktrace: NSObject {
	public let frames: [Frame]
	
	internal convenience init?(appleCrashTreadBacktraceDict: [String: AnyObject]?, appleCrashBinaryImagesDicts: [[String: AnyObject]]?) {
		
		guard let appleCrashTreadBacktraceDict = appleCrashTreadBacktraceDict, appleCrashBinaryImagesDicts = appleCrashBinaryImagesDicts else {
			return nil
		}
		
		let frames = (appleCrashTreadBacktraceDict["contents"] as? [[String: AnyObject]])?
			.flatMap({Frame(appleCrashFrameDict: $0, appleCrashBinaryImagesDicts: appleCrashBinaryImagesDicts)})
		self.init(frames: frames)
		
	}
	
	@objc public init(frames: [Frame]?) {
		self.frames = frames ?? []
	}
}

extension Stacktrace: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"frames": frames,
			]
	}
}

//if(showRegisters)
//{
//	result[@"vars"] = frame[@"registers"][@"basic"];
//}

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
	public var inApp: Bool?
	
	
	var fileName: String? {
		guard let file = file else { return nil }
		return (file as NSString).lastPathComponent
	}
	
	var culprit: String? {
		guard let fileName = fileName, line = line, function = function else { return nil }
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
	
	internal typealias MemoryAddress = UInt64

	internal convenience init?(appleCrashFrameDict frameDict: [String: AnyObject], appleCrashBinaryImagesDicts: [[String: AnyObject]]) {
		
		if let instructionAddress = Frame.asMemoryAddress(frameDict["instruction_addr"]),
			binaryImage = Frame.getBinaryImage(appleCrashBinaryImagesDicts, address: instructionAddress) {
			
			self.init()
			
			self.function = frameDict["symbol_name"] as? String
			
			self.inApp = (binaryImage["name"] as? String)?.containsString("/Bundle/Application/") ?? false
			self.package = binaryImage["name"] as? String
			
			self.imageAddress = Frame.getHexAddress(binaryImage["image_addr"])
			self.instructionAddress = Frame.getHexAddress(frameDict["instruction_addr"])
			self.symbolAddress = Frame.getHexAddress(frameDict["symbol_addr"])
		} else {
			return nil
		}
	}
	
	private class func asMemoryAddress(object: AnyObject?) -> MemoryAddress? {
		guard let object = object else { return nil }
		
		switch object {
		case let object as NSNumber:
			return object.unsignedLongLongValue
		case let object as Int64:
			return UInt64(object)
		default:
			return nil
		}
	}
	
	private class func getHexAddress(object: AnyObject?) -> String? {
		return getHexAddress(asMemoryAddress(object))
	}
	
	internal class func getHexAddress(address: MemoryAddress?) -> String? {
		guard let address = address else { return nil }
		return String(format: "0x%x", address)
	}
	
	private class func getBinaryImage(binaryImages: [[String: AnyObject]], address: MemoryAddress) -> [String: AnyObject]? {
		for binaryImage in binaryImages {
			if let imageStart = asMemoryAddress(binaryImage["image_addr"]),
				imageSize = asMemoryAddress(binaryImage["image_size"]) {
				
				let imageEnd = imageStart + imageSize
				if address >= imageStart && address < imageEnd {
					return binaryImage
				}
				
			}
		}
		
		return nil
	}
}

extension Frame: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [:]
			.set("filename", value: fileName)
			.set("function", value: function)
			.set("module", value: module)
			.set("lineno", value: line)
	}
}