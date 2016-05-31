//
//  Sentry.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/16/15.
//
//

import Foundation

// This is declared here to keep namespace compatibility with objc
@objc public enum SentryLog: Int, CustomStringConvertible {
	case None, Error, Debug

	public var description: String {
		switch self {
		case .None: return ""
		case .Error: return "Error"
		case .Debug: return "Debug"
		}
	}

	internal func log(message: String) {
		guard rawValue <= SentryClient.logLevel.rawValue else { return }
		print("SentrySwift - \(description):: \(message)")
	}
}

@objc public class SentryClient: NSObject, EventProperties {

	// MARK: - Static Attributes
	
	public static var shared: SentryClient?
	public static var logLevel: SentryLog = .None


	// MARK: - Enums

	internal struct Info {
		static let version: String = "0.2.1"
		static let sentryVersion: Int = 7
	}


	// MARK: - Attributes
	
	internal let dsn: DSN
	internal(set) var crashHandler: CrashHandler? {
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


	/// Creates a Sentry object to use for reporting
	internal init(dsn: DSN) {
		self.dsn = dsn
		super.init()
		sendEventsOnDisk()
	}
	
	/// Creates a Sentry object iff a valid DSN is provided
	@objc public convenience init?(dsnString: String) {
		guard let dsn = DSN(dsnString) else {
			return nil
		}
		self.init(dsn: dsn)
	}
	
	/*
	Reports message to Sentry with the given level
	- Parameter message: The message to send to Sentry
	- Parameter level: The severity of the message
	*/
	@objc public func captureMessage(message: String, level: SentrySeverity = .Info) {
		let event = Event(message, level: level)
		captureEvent(event)
	}

	/// Reports given event to Sentry
	@objc public func captureEvent(event: Event) {
		captureEvent(event, useClientProperties: true)
	}
	
	/*
	Reports given event to Sentry
	- Parameter event: An event struct
	- Parameter useClientProperties: Should the client's user, tags and extras also be reported (default is `true`)
	*/
	private func captureEvent(event: Event, useClientProperties: Bool = true) {
		var mutableEvent = event

		// Don't allow client attributes to be used when reporting an `Exception`
		if useClientProperties && mutableEvent.level != .Fatal {
			mutableEvent.mergeProperties(from: self)
		}

		if mutableEvent.level == .Error && mutableEvent.level != .Fatal {
			mutableEvent.breadcrumbsSerialized = breadcrumbs.serialized
			breadcrumbs.clear()
		}
		
		sendEvent(mutableEvent) { [weak self] success in
			guard !success else { return }
			self?.saveEvent(mutableEvent)
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
