//
//  Event.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/16/15.
//
//

import Foundation

public typealias EventTags = [String: String]
public typealias EventModules = [String: String]
public typealias EventExtra = [String: AnyObject]
public typealias EventFingerprint = [String]

/// A struct to hold event properties
@objc public class Event: NSObject, EventProperties {
	
	public static let platform = "swift"
	
	// MARK: Required
	public let eventID: String = {
		return NSUUID().UUIDString
			.stringByReplacingOccurrencesOfString("-", withString: "")
	}()
	public var message: String
	public var timestamp: NSDate = NSDate()
	public var level: SentrySeverity = .Error
	public var platform: String = Event.platform
	
	// MARK: Optional
	public var logger: String?
	public var culprit: String?
	public var serverName: String?
	public var releaseVersion: String?
	public var tags: EventTags?
	public var modules: EventModules?
	public var extra: EventExtra?
	public var fingerprint: EventFingerprint?
	
	public var user: User?
	public var appleCrashReport: AppleCrashReport?
	var breadcrumbsSerialized: BreadcrumbStore.SerializedType?
	
	public typealias BuildEvent = (inout Event) -> Void
	
	/// Creates an event
	/// - Paramter message: A message
	/// - Paramter build: A closure that passes an event to build upon
	public static func build(message: String, build: BuildEvent) -> Event {
		var event = Event(message, timestamp: NSDate())
		build(&event)
		return event
	}
	
	/// Creates an event
	/// - Paramter message: A message
	/// - Paramter timestamp: A timestamp
	/// - Paramter level: A severity level
	/// - Paramter platform: A platform
	/// - Paramter logger: A logger
	/// - Paramter culprit: A culprit
	/// - Paramter serverName: A server name
	/// - Paramter release: A release
	/// - Paramter tags: A dictionary of tags
	/// - Paramter modules: A dictionary of modules
	/// - Paramter extras: A dictionary of extras
	/// - Paramter fingerprint: A array of fingerprints
	/// - Paramter user: A user object
	/// - Paramter appleCrashReport: An apple crash report
	@objc public init(_ message: String, timestamp: NSDate = NSDate(), level: SentrySeverity = .Error, logger: String? = nil, culprit: String? = nil, serverName: String? = nil, release: String? = nil, tags: EventTags? = nil, modules: EventModules? = nil, extra: EventExtra? = nil, fingerprint: EventFingerprint? = nil, user: User? = nil, appleCrashReport: AppleCrashReport? = nil) {
		
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
		
		// Optional interfaces
		self.user = user
		self.appleCrashReport = appleCrashReport
	}
}

extension Event: EventSerializable {
	typealias Attribute = (key: String, value: AnyObject?)
	
	public typealias SerializedType = [String: AnyObject]
	
	/// A dictionary of attributes defined by this event
	public var serialized: SerializedType {
		
		// Create attributes list
		let attributes: [Attribute] = [
			// Required
			("event_id", eventID),
			("message", message),
			("timestamp", timestamp.iso8601),
			("level", level.name),
			("platform", platform),
			
			// Optional
			("logger", logger),
			("culprit", culprit),
			("server_name", serverName),
			("release", releaseVersion),
			("tags", tags),
			("modules", modules),
			("extra", extra),
			("fingerprint", fingerprint),
			
			// Interfaces
			("user", user?.serialized),
			("applecrashreport", appleCrashReport?.serialized),
			("breadcrumbs", breadcrumbsSerialized)
		]
		
		// Reduce attributes so only non-nill attribute are sent
		return attributes.reduce(SerializedType()) { (var serializedType, attribute) -> SerializedType in
			if let value = attribute.value {
				serializedType[attribute.key] = value
			}
			return serializedType
		}
	}
	

}



@objc public enum SentrySeverity: Int {
	case Fatal
	case Error
	case Warning
	case Info
	case Debug
	
	public var name: String {
		switch self {
		case Fatal: return "fatal"
		case Error: return "error"
		case Warning: return "warning"
		case Info: return "info"
		case Debug: return "debug"
		}
	}
}

// MARK: Date

private let dateFormatter: NSDateFormatter  = {
	let df = NSDateFormatter()
	df.locale = NSLocale(localeIdentifier: "en_US_POSIX")
	df.timeZone = NSTimeZone(abbreviation: "UTC")
	df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
	return df
}()

extension NSDate {
	public static func fromISO8601(iso8601String: String) -> NSDate? {
		return dateFormatter.dateFromString(iso8601String)
	}
	
	public var iso8601: String {
		return dateFormatter.stringFromDate(self)
	}
}