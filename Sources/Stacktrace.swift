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
	
	internal convenience init?(appleCrashTreadBacktraceDict: [String: AnyObject]?, binaryImages: [BinaryImage]?) {
		
		guard let appleCrashTreadBacktraceDict = appleCrashTreadBacktraceDict, let binaryImages = binaryImages else {
			return nil
		}
		
		let frames = (appleCrashTreadBacktraceDict["contents"] as? [[String: AnyObject]])?
			.flatMap({Frame(appleCrashFrameDict: $0, binaryImages: binaryImages)})
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
			"frames": frames.map({$0.serialized}),
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
			
			#if swift(>=3.0)
				self.inApp = binaryImage.name?.contains("/Bundle/Application/") ?? false
			#else
				self.inApp = binaryImage.name?.containsString("/Bundle/Application/") ?? false
			#endif
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
		return [:]
			.set("filename", value: fileName)
			.set("function", value: function)
			.set("module", value: module)
			.set("lineno", value: line)
			.set("package", value: package)
			.set("image_addr", value: imageAddress)
			.set("instruction_addr", value: instructionAddress)
			.set("symbol_addr", value: symbolAddress)
			.set("in_app", value: inApp)
	}
}
