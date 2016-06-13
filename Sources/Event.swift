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
public typealias EventExtra = [String: AnyObject]
public typealias EventFingerprint = [String]

// This is declared here to keep namespace compatibility with objc
@objc public enum SentrySeverity: Int, CustomStringConvertible {
	case Fatal, Error, Warning, Info, Debug

	public var description: String {
		switch self {
		case Fatal: return "fatal"
		case Error: return "error"
		case Warning: return "warning"
		case Info: return "info"
		case Debug: return "debug"
		}
	}
}

/// A class that defines an event to be reported
@objc public class Event: NSObject, EventProperties {

	public typealias BuildEvent = (inout Event) -> Void

	// MARK: - Required Attributes

	public let eventID: String = NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "")
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
	public var exception: [Exception]?
	public var appleCrashReport: AppleCrashReport?
	internal var breadcrumbsSerialized: BreadcrumbStore.SerializedType?

    // for internal use for now, must be convertible using NSJSONSerialization
    var stackTrace: [String: AnyObject]?
	
	/*
	Creates an event
	- Parameter message: A message
	- Parameter build: A closure that passes an event to build upon
	*/
	public static func build(message: String, build: BuildEvent) -> Event {
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
	- Parameter exception: An array of `Exception` objects
	- Parameter appleCrashReport: An apple crash report
	*/
	@objc public init(_ message: String, timestamp: NSDate = NSDate(), level: SentrySeverity = .Error, logger: String? = nil, culprit: String? = nil, serverName: String? = nil, release: String? = nil, tags: EventTags = [:], modules: EventModules? = nil, extra: EventExtra = [:], fingerprint: EventFingerprint? = nil, user: User? = nil, exception: [Exception]? = nil, appleCrashReport: AppleCrashReport? = nil) {

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
		self.exception = exception
		self.appleCrashReport = appleCrashReport

		super.init()
	}
}

extension Event: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal typealias Attribute = (key: String, value: AnyObject?)
	
	var sdk: [String: String]? {
		return [
			"name": "sentry-swift",
			"version": SentryClient.Info.version
		]
	}
	
	var device: [String: String]? {
		guard let os = os, version = version else {
			return nil
		}
		
		return [
			"name": os,
			"version": version
		]
	}
	
	var os: String? {
		#if os(iOS)
			return "iOS"
		#elseif os(tvOS)
			return "tvOS"
		#elseif os(OSX)
			return "macOS"
		#else
			return nil
		#endif
	}
	
	var version: String? {
		#if os(iOS) || os(tvOS)
			return UIDevice.currentDevice().systemVersion
		#elseif os(OSX)
			return NSProcessInfo.processInfo().operatingSystemVersionString
		#else
			return nil
		#endif
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
			("device", device),

			// Optional
			("logger", logger),
			("culprit", culprit),
			("server_name", serverName),
			("release", releaseVersion),
			("tags", NSJSONSerialization.isValidJSONObject(tags) ? tags : nil),
			("modules", modules),
			("extra", NSJSONSerialization.isValidJSONObject(extra) ? extra : nil),
			("fingerprint", fingerprint),

			// Interfaces
			("user", user?.serialized),
			("exception", [:].set("values", value: exception?.map() { $0.serialized }.flatMap() { $0 })),
			("applecrashreport", appleCrashReport?.serialized),
			("breadcrumbs", breadcrumbsSerialized),
			("stacktrace", stackTrace),
		]

		var ret: [String: AnyObject] = [:]
		attributes.filter() { $0.value != nil }.forEach() { ret.updateValue($0.value!, forKey: $0.key) }
		return ret
	}
}
