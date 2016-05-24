//
//  Breadcrumb.swift
//  SentrySwift
//
//  Created by Josh Holtz on 3/24/16.
//
//

import Foundation

// Note: These Breadcrumbs are created an convenience initializers
// due to compatibility with Objective-C. These should really be
// enums with associative values (because much cleaner) but
// Objective-C does not recognize them.

/// A class used to represent the breadcrumbs attached to events
@objc public class Breadcrumb: NSObject {
	
	public var timestamp: NSDate
	public var category: String
	
	public var type: String?
	public var message: String?
	public var data: [String: AnyObject]
	public var level: SentrySeverity?
	
	/// Creates a user
	public init(category: String, timestamp: NSDate = NSDate(), message: String? = nil, type: String? = nil, level: SentrySeverity? = nil, data: [String: AnyObject]? = nil) {
		self.category = category
		self.timestamp = timestamp
		self.message = message
		self.type = type
		self.data = data ?? [:]
	}

}

extension Dictionary {
	
	// Sets the key and value but only if value is non-nil
	func set(key: Key, value: Value?) -> Dictionary<Key, Value> {
		guard let value = value else { return self }
		
		var newDict = self
		newDict[key] = value
		
		return newDict
	}
	
}

extension Breadcrumb {
	
	public convenience init(category: String, timestamp: NSDate = NSDate(), message: String? = nil, level: SentrySeverity? = nil, data: [String: AnyObject]? = nil, to: String, from: String? = nil) {
		
		let navigationData = (data ?? [:])
			.set("to", value: to)
			.set("from", value: from)
		
		self.init(category: category, timestamp: timestamp, message: message, type: "navigation", level: level, data: navigationData)
	}
	
	public convenience init(category: String, timestamp: NSDate = NSDate(), message: String? = nil, level: SentrySeverity? = nil, data: [String: AnyObject]? = nil, url: String, method: String, statusCode: Int? = nil, reason: String? = nil) {
		
		let httpData = (data ?? [:])
			.set("url", value: url)
			.set("method", value: method)
			.set("status_code", value: statusCode)
			.set("reason", value: "reason")
		
		self.init(category: category, timestamp: timestamp, message: message, type: "http", level: level, data: httpData)
	}
	
}

extension Breadcrumb: EventSerializable {
	public typealias SerializedType = SerializedTypeDictionary
	public var serialized: SerializedType {
		return [
			"category": category,
			"timestamp": timestamp.iso8601,
			"data": data
		]
		.set("type", value: type)
		.set("message", value: message)
		.set("level", value: level?.name)
	}
}
