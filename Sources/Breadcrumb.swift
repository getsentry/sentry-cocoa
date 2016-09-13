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

	public let timestamp: Date
	public var category: String

	public var type: String?
	public var message: String?
	public var data: [String: Any]
	public var level: SentrySeverity // can't be optional because @objc can't handle optional enums


	/// Creates a breadcrumb
	@objc public init(category: String, timestamp: Date = Date(), message: String? = nil, type: String? = nil, level: SentrySeverity = .info, data: [String: Any]? = nil) {
		self.category = category
		self.timestamp = timestamp
		self.message = message
		self.type = type
		self.data = data ?? [:]
		self.level = level

		super.init()
	}

	/// Conveneince init for a "navigation" type breadcrumb
	public convenience init(category: String, timestamp: Date = Date(), message: String? = nil, level: SentrySeverity = .info, data: [String: Any]? = nil, to: String, from: String? = nil) {
		let navigationData: [String: Any] = (data ?? [:])
		.set(key: "to", value: to)
		.set(key: "from", value: from)

		self.init(category: category, timestamp: timestamp, message: message, type: "navigation", level: level, data: navigationData)
	}

	/// Conveneince init for an "http" type breadcrumb (-999 workaround because @objc can't handle optional Int)
	public convenience init(category: String, timestamp: Date = Date(), message: String? = nil, level: SentrySeverity = .info, data: [String: Any]? = nil, url: String, method: String, statusCode: Int = -999, reason: String? = nil) {
		let httpData: [String: Any] = (data ?? [:])
		.set(key: "url", value: url)
		.set(key: "method", value: method)
		.set(key: "status_code", value: statusCode == -999 ? nil : statusCode)
		.set(key: "reason", value: "reason")

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
		.set(key: "type", value: type)
		.set(key: "message", value: message)
		.set(key: "level", value: level.description)
	}
}
