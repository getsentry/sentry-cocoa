//
//  Breadcrumb.swift
//  SentrySwift
//
//  Created by Josh Holtz on 3/24/16.
//
//

import Foundation

/// A class used to represent the breadcrumbs leading up to an events
@objc public class Breadcrumb: NSObject {

	// MARK: - Attributes

	public let timestamp: NSDate
	public var category: String

	public var type: String?
	public var message: String?
	public var data: [String: AnyType]
	public var level: SentrySeverity // can't be optional because @objc can't handle optional enums


	/// Creates a breadcrumb
	@objc public init(category: String, timestamp: NSDate = NSDate(), message: String? = nil, type: String? = nil, level: SentrySeverity = .Info, data: [String: AnyType]? = nil) {
		self.category = category
		self.timestamp = timestamp
		self.message = message
		self.type = type
		self.data = data ?? [:]
		self.level = level

		super.init()
	}

	/// Conveneince init for a "navigation" type breadcrumb
	public convenience init(category: String, timestamp: NSDate = NSDate(), message: String? = nil, level: SentrySeverity = .Info, data: [String: AnyType]? = nil, to: String, from: String? = nil) {
		let navigationData: [String: AnyType] = (data ?? [:])
		.set("to", value: to)
		.set("from", value: from)

		self.init(category: category, timestamp: timestamp, message: message, type: "navigation", level: level, data: navigationData)
	}

	/// Conveneince init for an "http" type breadcrumb (-999 workaround because @objc can't handle optional Int)
	public convenience init(category: String, timestamp: NSDate = NSDate(), message: String? = nil, level: SentrySeverity = .Info, data: [String: AnyType]? = nil, url: String, method: String, statusCode: Int = -999, reason: String? = nil) {
		let httpData: [String: AnyType] = (data ?? [:])
		.set("url", value: url)
		.set("method", value: method)
		.set("status_code", value: statusCode == -999 ? nil : statusCode)
		.set("reason", value: "reason")

		self.init(category: category, timestamp: timestamp, message: message, type: "http", level: level, data: httpData)
	}
}

extension Breadcrumb: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"category": category,
			"timestamp": timestamp.iso8601,
			"data": data
		]
		.set("type", value: type)
		.set("message", value: message)
		.set("level", value: level.description)
	}
}
