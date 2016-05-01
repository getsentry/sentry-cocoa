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
	
	public var type: String
	public var timestamp: NSDate
	public var data: [String: AnyObject]
	
	/// Creates a user
	public init(type: String, timestamp: NSDate = NSDate(), data: [String: AnyObject]) {
		self.type = type
		self.timestamp = timestamp
		self.data = data
	}
	
	/// Creates a "message" type of breadcrumbs
	/// - Parameter message: A message
	/// - Parameter logger: A logger
	/// - Parameter level: A level
	/// - Parameter classifier: A classifier
	public convenience init(message: String, logger: String? = nil, level: SentrySeverity? = nil, classifier: String? = nil) {
		let data: [String: AnyObject] = ["message": message]
			.set("logger", value: logger)
			.set("level", value: level?.name)
			.set("classifier", value: classifier)
		
		self.init(
			type: "message",
			data: data
		)
	}
	
	/// Creates an "rpc" type of breadcrumbs
	/// - Parameter endpoint: An endpoint
	/// - Parameter params: A params
	/// - Parameter classifier: A classifier
	public convenience init(endpoint: String, params: [String: AnyObject]? = nil, classifier: String? = nil) {
		let data: [String: AnyObject] = ["endpoint": endpoint]
			.set("params", value: params)
			.set("classifier", value: classifier)
		
		self.init(
			type: "rpc",
			data: data
		)
	}
	
	/// Creates an "http_request" type of breadcrumbs
	/// - Parameter endpoint: An endpoint
	/// - Parameter method: A method
	/// - Parameter headers: some headers
	/// - Parameter statusCode: A status code
	/// - Parameter response: A response
	/// - Parameter reason: A reason
	/// - Parameter classifier: A classifier
	public convenience init(url: String, method: String? = nil, headers: [String: AnyObject]? = nil, statusCode: Int? = nil, response: String? = nil, reason: String? = nil, classifier: String? = nil) {
		let data: [String: AnyObject] = ["url": url]
			.set("method", value: method)
			.set("headers", value: headers)
			.set("statusCode", value: statusCode)
			.set("response", value: response)
			.set("reason", value: reason)
			.set("classifier", value: classifier)
		
		self.init(
			type: "http_request",
			data: data
		)
	}
	
	/// Creates an "query" type of breadcrumbs
	/// - Parameter query: A query
	/// - Parameter params: A params
	/// - Parameter classifier: A classifier
	public convenience init(query: String, params: String? = nil, classifier: String? = nil) {
		let data: [String: AnyObject] = ["query": query]
			.set("params", value: params)
			.set("classifier", value: classifier)
		
		self.init(
			type: "query",
			data: data
		)
	}
	
	/// Creates an "ui_event" type of breadcrumbs
	/// - Parameter type: A type
	/// - Parameter target: A target
	/// - Parameter classifier: A classifier
	public convenience init(uiEventType: String, target: String? = nil, classifier: String? = nil) {
		let data: [String: AnyObject] = ["type": uiEventType]
			.set("target", value: target)
			.set("classifier", value: classifier)
		
		self.init(
			type: "ui_event",
			data: data
		)
	}
	
	/// Creates an "navigation" type of breadcrumbs
	/// - Parameter to: A location going to
	/// - Parameter from: A location going from
	public convenience init(to: String, from: String? = nil) {
		let data: [String: AnyObject] = ["to": to]
			.set("from", value: from)
		
		self.init(
			type: "navigation",
			data: data
		)
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

extension Breadcrumb: EventSerializable {
	public typealias SerializedType = SerializedTypeDictionary
	public var serialized: SerializedType {
		return [
			"type": type,
			"timestamp": timestamp.iso8601,
			"data": data
		]
	}
}
