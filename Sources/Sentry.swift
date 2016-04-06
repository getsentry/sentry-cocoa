//
//  Sentry.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/16/15.
//
//

import Foundation

public struct SentryInfo {
	public static let version: Int = 1
	public static let sentryVersion: Int = 7
}

@objc public enum SentryLog: Int {
	case None = 0, Error = 1, Debug = 2
	
	var name: String {
		switch self {
		case .None: return ""
		case .Error: return "Error"
		case .Debug: return "Debug"
		}
	}
	
	func log(string: String) {
		guard rawValue <= SentryClient.logLevel.rawValue else { return }
		print("SentrySwift - \(name):: \(string)")
	}
}


@objc public class SentryClient: NSObject, EventProperties {

	// MARK: Static
	
	public static var shared: SentryClient?
	public static var logLevel = SentryLog.None
	
	// MARK: Instance
	
	public let dsn: DSN
	@objc public var crashHandler: CrashHandler? {
		didSet {
			crashHandler?.startCrashReporting { (event) -> () in
				self.captureEvent(event, useClientProperties: false)
			}
		}
	}
	
	public lazy var breadcrumbs: BreadcrumbStore = {
		let store = BreadcrumbStore()
		store.storeUpdated = {
			self.crashHandler?.breadcrumbsSerialized = $0.serialized
		}
		return store
	}()

	// MARK: EventProperties
	public var tags: EventTags? = nil {
		didSet { crashHandler?.tags = tags }
	}
	public var extra: EventExtra? = nil {
		didSet { crashHandler?.extra = extra }
	}
	public var user: User? = nil {
		didSet { crashHandler?.user = user }
	}

	/// Creates a SentryClient
	/// - Parameter dsn: The "client key"
	/// - Returns: A SentryClient used to capture messages and exceptions
	@objc public init(dsn: DSN) {
		self.dsn = dsn
		super.init()
		sendEventsOnDisk()
	}
	
	/// Creates a SentryClient
	/// - Parameter : dsn: The "client key"
	/// - Returns: A SentryClient used to capture messages and exceptions
	@objc public convenience init?(dsnString: String) {
		guard let dsn = DSN(dsnString) else {
			return nil
		}
		self.init(dsn: dsn)
	}
	
	/// The operating system this client is running on
	public var os: OS {
		#if os(iOS)
			return .IOS
		#elseif os(OSX)
			return .OSX
		#else
			return .Other
		#endif
	}
	
	/// Captures message and level to create an event to report
	/// - Parameter message: A message for the event
	/// - Parameter level: A severity level for the event
	public func captureMessage(message: String, level: SentrySeverity = .Info) {
		let event = Event(message, level: level)
		captureEvent(event)
	}
	
	/// Captures event to report
	/// - Parameter event: An event
	@objc public func captureEvent(event: Event) {
		captureEvent(event, useClientProperties: true)
	}
	
	/// A private function that will optionally merge client properties into an event.
	/// Usage: Don't merge client properties from crash reports.
	private func captureEvent(event: Event, useClientProperties: Bool) {
		if useClientProperties {
			event.mergeProperties(self)
			
			switch event.level {
			case .Fatal, .Error:
				event.breadcrumbsSerialized = breadcrumbs.serialized
				breadcrumbs.clear()
			default: ()
			}
		}
		
		sendEvent(event) { success in
			guard !success else { return }
			self.saveEvent(event)
		}
	}

	/// Attempts to send all events that are saved on disk
	private func sendEventsOnDisk() {
		let events = savedEvents()
		
		for savedEvent in events {
			sendData(savedEvent.data) { success in
				guard success else { return }
				savedEvent.deleteEvent()
			}
		}
	}
}

/// Platforms that this client is running on
public enum OS {
	case IOS, OSX, Other
}