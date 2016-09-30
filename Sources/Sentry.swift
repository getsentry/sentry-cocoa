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

	internal func log(_ message: String) {
		guard rawValue <= SentryClient.logLevel.rawValue else { return }
		print("SentrySwift - \(description):: \(message)")
	}
}

#if swift(>=3.0)
	public typealias AnyType = Any
#else
	public typealias AnyType = AnyObject
	internal typealias Error = ErrorType
	internal typealias ProcessInfo = NSProcessInfo
	internal typealias JSONSerialization = NSJSONSerialization
	internal typealias Bundle = NSBundle
#endif

internal enum SentryError: Error {
	case InvalidDSN
}

@objc public class SentryClient: NSObject, EventProperties {

	// MARK: - Static Attributes
	
	public static var shared: SentryClient?
	public static var logLevel: SentryLog = .None


	// MARK: - Enums

	internal struct Info {
		static let version: String = "0.4.1"
		static let sentryVersion: Int = 7
	}


	// MARK: - Attributes
	
	internal let dsn: DSN
	internal(set) var crashHandler: CrashHandler? {
		didSet {
			crashHandler?.startCrashReporting()
			crashHandler?.releaseVersion = releaseVersion
			crashHandler?.tags = tags
			crashHandler?.extra = extra
			crashHandler?.user = user
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

	public var releaseVersion: String? {
		didSet { crashHandler?.releaseVersion = releaseVersion }
	}
	public var tags: EventTags = [:] {
		didSet { crashHandler?.tags = tags }
	}
	public var extra: EventExtra = [:] {
		didSet { crashHandler?.extra = extra }
	}
	public var user: User? = nil {
		didSet { crashHandler?.user = user }
	}


	/// Creates a Sentry object to use for reporting
	internal init(dsn: DSN) {
		self.dsn = dsn
		
		#if swift(>=3.0)
			self.releaseVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
		#else
			self.releaseVersion = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String
		#endif
		
		super.init()
		sendEventsOnDisk()
	}
	
	/// Creates a Sentry object iff a valid DSN is provided
	@objc public convenience init?(dsnString: String) {
		// Silently not creating a client if dsnString is empty string
		if dsnString.isEmpty {
			SentryLog.Debug.log("DSN provided was empty - not creating a SentryClient object")
			return nil
		}
		
		// Try to create a client with a DSN string
		// Log error if cannot make one
		do {
			let dsn = try DSN(dsnString)
			self.init(dsn: dsn)
		} catch SentryError.InvalidDSN {
			SentryLog.Error.log("DSN is invalid")
			return nil
		} catch {
			SentryLog.Error.log("DSN is invalid")
			return nil
		}
	}
	
	/*
	Reports message to Sentry with the given level
	- Parameter message: The message to send to Sentry
	- Parameter level: The severity of the message
	*/
	@objc public func captureMessage(_ message: String, level: SentrySeverity = .Info) {
		let event = Event(message, level: level)
		captureEvent(event)
	}

	/// Reports given event to Sentry
	@objc public func captureEvent(_ event: Event) {
		captureEvent(event, useClientProperties: true)
	}
	
	/*
	Reports given event to Sentry
	- Parameter event: An event struct
	- Parameter useClientProperties: Should the client's user, tags and extras also be reported (default is `true`)
	*/
	internal func captureEvent(_ event: Event, useClientProperties: Bool = true, completed: ((Bool) -> ())? = nil) {

		// Don't allow client attributes to be used when reporting an `Exception`
		if useClientProperties && event.level != .Fatal {
			event.user = event.user ?? user
			event.releaseVersion = event.releaseVersion ?? releaseVersion

			if JSONSerialization.isValidJSONObject(tags) {
				event.tags.unionInPlace(tags)
			}

			if JSONSerialization.isValidJSONObject(extra) {
				event.extra.unionInPlace(extra)
			}
		}

		if event.level == .Error && event.level != .Fatal {
			event.breadcrumbsSerialized = breadcrumbs.serialized
			breadcrumbs.clear()
		}
		
		sendEvent(event) { [weak self] success in
			completed?(success)
			guard !success else { return }
			self?.saveEvent(event)
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
