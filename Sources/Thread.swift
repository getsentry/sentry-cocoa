//
//  Thread.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/25/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.exception`
@objc public class Thread: NSObject {
	public let id: Int
	public let crashed: Bool?
	public let current: Bool?
	public let name: String?
	public let stacktrace: Stacktrace?
	
	/// Creates `Exception` object
	@objc public init(id: Int, crashed: Bool = false, current: Bool = false, name: String? = nil, stacktrace: Stacktrace? = nil) {
		self.id = id
		self.crashed = crashed
		self.current = current
		self.name = name
		self.stacktrace = stacktrace
		
		super.init()
	}
	
	internal convenience init?(threadCrashDict: [String: AnyObject]) {
		guard let id = threadCrashDict["index"] as? Int else {
			return nil
		}
		
		let crashed = threadCrashDict["crashed"] as? Bool ?? false
		let current = threadCrashDict["current_thread"] as? Bool ?? false
		let name = threadCrashDict["name"] as? String
		
		// TODO: Do something with this stacktrace
		self.init(id: id, crashed: crashed, current: current, name: name, stacktrace: nil)
	}
}

extension Thread: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"id": id,
			]
			.set("crashed", value: crashed)
			.set("current", value: current)
			.set("name", value: name)
			.set("stacktrace", value: stacktrace)
	}
}
