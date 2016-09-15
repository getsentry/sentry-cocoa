//
//  Event.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/16/15.
//
//

import Foundation

#if os(iOS) || os(tvOS)
	import UIKit
#endif

public typealias EventTags = [String: String]
public typealias EventModules = [String: String]
public typealias EventExtra = [String: AnyType]
public typealias EventFingerprint = [String]

// This is declared here to keep namespace compatibility with objc
@objc public enum SentrySeverity: Int, CustomStringConvertible {
	case Fatal, Error, Warning, Info, Debug

	public var description: String {
		switch self {
		case .Fatal: return "fatal"
		case .Error: return "error"
		case .Warning: return "warning"
		case .Info: return "info"
		case .Debug: return "debug"
		}
	}
}

/// A class that defines an event to be reported
@objc public class Event: NSObject, EventProperties {

	public typealias BuildEvent = (inout Event) -> Void

	// MARK: - Required Attributes

	#if swift(>=3.0)
		public let eventID: String = NSUUID().uuidString.replacingOccurrences(of: "-", with: "")
	#else
		public let eventID: String = NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "")
	#endif
	public var message: String
	public var timestamp: NSDate = NSDate()
	public var level: SentrySeverity = .Error
	public var platform: String = "cocoa"


	// MARK: - Optional Attributes

	public var logger: String?
	public var culprit: String?
	public var serverName: String?
	public var releaseVersion: String?
	public var tags: EventTags = [:]
	public var modules: EventModules?
	public var extra: EventExtra = [:]
	public var fingerprint: EventFingerprint?


	// MARK: - Optional Interfaces

	public var user: User?
	public var threads: [Thread]?
	public var exceptions: [Exception]?
	public var stacktrace: Stacktrace?
	public var appleCrashReport: AppleCrashReport?
	internal var breadcrumbsSerialized: BreadcrumbStore.SerializedType?
	
	internal var debugMeta: DebugMeta?
	
	/*
	Creates an event
	- Parameter message: A message
	- Parameter build: A closure that passes an event to build upon
	*/
	public static func build(_ message: String, build: BuildEvent) -> Event {
		var event: Event = Event(message, timestamp: NSDate())
		build(&event)
		return event
	}

	/*
	Creates an event
	- Parameter message: A message
	- Parameter timestamp: A timestamp
	- Parameter level: A severity level
	- Parameter platform: A platform
	- Parameter logger: A logger
	- Parameter culprit: A culprit
	- Parameter serverName: A server name
	- Parameter release: A release
	- Parameter tags: A dictionary of tags
	- Parameter modules: A dictionary of modules
	- Parameter extras: A dictionary of extras
	- Parameter fingerprint: A array of fingerprints
	- Parameter user: A user object
	- Parameter exceptions: An array of `Exception` objects
	- Parameter stacktrace: An array of `Stacktrace` objects
	- Parameter appleCrashReport: An apple crash report
	*/
	@objc public init(_ message: String, timestamp: NSDate = NSDate(), level: SentrySeverity = .Error, logger: String? = nil, culprit: String? = nil, serverName: String? = nil, release: String? = nil, tags: EventTags = [:], modules: EventModules? = nil, extra: EventExtra = [:], fingerprint: EventFingerprint? = nil, user: User? = nil, exceptions: [Exception]? = nil, stacktrace: Stacktrace? = nil, appleCrashReport: AppleCrashReport? = nil) {

		// Required
		self.message = message
		self.timestamp = timestamp
		self.level = level

		// Optional
		self.logger = logger
		self.culprit = culprit
		self.serverName = serverName
		self.releaseVersion = release
		self.tags = tags
		self.modules = modules
		self.extra = extra
		self.fingerprint = fingerprint

		// Optional Interfaces
		self.user = user
		self.exceptions = exceptions
		self.stacktrace = stacktrace
		self.appleCrashReport = appleCrashReport

		super.init()
	}
}

extension Event: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal typealias Attribute = (key: String, value: AnyType?)
	
	var sdk: [String: String]? {
		return [
			"name": "sentry-swift",
			"version": SentryClient.Info.version
		]
	}

	/// Dictionary version of attributes set in event
	internal var serialized: SerializedType {

		// Create attributes list
		let attributes: [Attribute] = [
			// Required
			("event_id", eventID),
			("message", message),
			("timestamp", timestamp.iso8601),
			("level", level.description),
			("platform", platform),
			
			// Computed
			("sdk", sdk),

			("contexts", Contexts().serialized),

			// Optional
			("logger", logger),
			("culprit", culprit),
			("server_name", serverName),
			("release", releaseVersion),
			("tags", JSONSerialization.isValidJSONObject(tags) ? tags : nil),
			("modules", modules),
			("extra", JSONSerialization.isValidJSONObject(extra) ? extra : nil),
			("fingerprint", fingerprint),

			// Interfaces
			("user", user?.serialized),
			("threads", [:].set("values", value: threads?.map() { $0.serialized })),
			("exception", [:].set("values", value: exceptions?.map() { $0.serialized })),
			("applecrashreport", appleCrashReport?.serialized),
			("breadcrumbs", breadcrumbsSerialized),
			("stacktrace", stacktrace?.serialized),
			
			("debug_meta", debugMeta?.serialized)
		]

		var ret: [String: AnyType] = [:]
		attributes.filter() { $0.value != nil }.forEach() { ret.updateValue($0.value!, forKey: $0.key) }
		return ret
	}
}
