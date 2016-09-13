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


@objc public class Frame: NSObject {
	public let file: String
	public let function: String
	public let module: String?
	
	public let line: Int
	
	var fileName: String {
		return (file as NSString).lastPathComponent
	}
	
	var culprit: String {
		return "\(fileName):\(line) \(function)"
	}
	
	/// Creates `Exception` object
	@objc public init(file: String, function: String, module: String? = nil, line: Int) {
		self.file = file
		self.function = function
		self.module = module
		
		self.line = line
		
		super.init()
	}

}

extension Frame: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"filename": fileName,
			"function": function
			]
			.set(key: "module", value: module)
			.set(key: "lineno", value: line)
	}
}
