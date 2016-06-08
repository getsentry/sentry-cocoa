//
//  KSCrashHandler.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/2/16.
//
//

import KSCrash
import Foundation

extension SentryClient {
	public func startCrashHandler() {
		crashHandler = KSCrashHandler()
	}
}

private typealias CrashDictionary = [String: AnyObject]

private let keyUser = "user"
private let keyEventTags = "event_tags"
private let keyEventExtra = "event_extra"
private let keyBreadcrumbsSerialized = "breadcrumbs_serialized"


/// A class to report crashes to Sentry built upon KSCrash
internal class KSCrashHandler: CrashHandler {

	// MARK: - Attributes

	private var installation: KSCrashSentryInstallation?

	// MARK: - EventProperties

	internal var tags: EventTags = [:] {
		didSet { updateUserInfo() }
	}
	internal var extra: EventExtra = [:] {
		didSet { updateUserInfo() }
	}
	internal var user: User? {
		didSet { updateUserInfo() }
	}


	// MARK: - CrashHandler

	internal var breadcrumbsSerialized: BreadcrumbStore.SerializedType? {
		didSet { updateUserInfo() }
	}

	/*
	Starts the crash reporting and sends any previously saved crash reports
	- Parameter createdEvent: A closure that passes in a created event
	*/
	internal func startCrashReporting(generatedEvent: GeneratedEvent) {
		
		if installation != nil { return }
		installation = KSCrashSentryInstallation(generatedEvent: generatedEvent)

		// Temporarily sets introspect to false due to KSCrash bug
		// -> https://github.com/kstenerud/KSCrash/issues/110
		KSCrash.sharedInstance().introspectMemory = false
		installation?.install()

		// Maps KSCrash reports in `Events`
		installation?.sendAllReportsWithCompletion() { (filteredReports, completed, error) -> Void in
			SentryLog.Debug.log("Sent \(filteredReports.count) report(s)")
		}
	}


	// MARK: - Private Helpers

	private func updateUserInfo() {
		var userInfo = CrashDictionary()
		userInfo[keyEventTags] = tags
		userInfo[keyEventExtra] = extra

		if let user = user?.serialized {
			userInfo[keyUser] = user
		}

		if let breadcrumbsSerialized = breadcrumbsSerialized {
			userInfo[keyBreadcrumbsSerialized] = breadcrumbsSerialized
		}

		KSCrash.sharedInstance().userInfo = userInfo
	}

}

class KSCrashSentryInstallation: KSCrashInstallation {
	
	private let generatedEvent: GeneratedEvent
	
	init(generatedEvent: GeneratedEvent) {
		self.generatedEvent = generatedEvent
		super.init(requiredProperties: [])
	}
	
	override func sink() -> KSCrashReportFilter! {
		return KSCrashReportSinkSentry(generatedEvent: generatedEvent)
	}
	
}

class KSCrashReportSinkSentry: NSObject, KSCrashReportFilter {
	
	private let generatedEvent: GeneratedEvent
	
	init(generatedEvent: GeneratedEvent) {
		self.generatedEvent = generatedEvent
		super.init()
	}
	
	func filterReports(reports: [AnyObject]!, onCompletion: KSCrashReportFilterCompletion!) {
		
		// Mapping reports
		let events = reports?
			.flatMap({$0 as? CrashDictionary})
			.map({mapReportToEvent($0)})
		
		// Propigating this generated event up so the SentryClient object can send it off
		for event in events ?? [] {
			generatedEvent(event: event)
		}
		
		onCompletion?(reports, true, nil)
	}
	
	private func mapReportToEvent(report: CrashDictionary) -> Event {
		SentryLog.Debug.log("Found report: \(report)")

		// Extract crash timestamp
		let timestamp: NSDate = {
			var date: NSDate?
			if let timestampStr = report["report"]?["timestamp"] as? String {
				let dateFormatter = NSDateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
				dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
				dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
				date = dateFormatter.dateFromString(timestampStr)
			}
			return date ?? NSDate()
		}()

		// Populate user info
		let userInfo = self.parseUserInfo(report["user"] as? CrashDictionary)

		// Generate Apple crash report
		let appleCrashReport: AppleCrashReport? = {
			guard let
				crash = report["crash"] as? [String: AnyObject],
				binaryImages = report["binary_images"] as? [[String: AnyObject]],
				system = report["system"] as? [String: AnyObject] else {
					return nil
				}
			return AppleCrashReport(crash: crash, binaryImages: binaryImages, system: system)
		}()

		/// Generate event to sent up to API
		/// Sends a blank message because server does stuff
		let event = Event.build("") {
			$0.level = .Fatal
			$0.timestamp = timestamp
			$0.tags = userInfo.tags ?? [:]
			$0.extra = userInfo.extra ?? [:]
			$0.user = userInfo.user
			$0.appleCrashReport = appleCrashReport
			$0.breadcrumbsSerialized = userInfo.breadcrumbsSerialized
		}
		
		return event
	}
	
	private func parseUserInfo(userInfo: CrashDictionary?) -> (tags: EventTags?, extra: EventExtra?, user: User?, breadcrumbsSerialized: BreadcrumbStore.SerializedType?) {
		return (
			userInfo?[keyEventTags] as? EventTags,
			userInfo?[keyEventExtra] as? EventExtra,
			User(dictionary: userInfo?[keyUser] as? [String: AnyObject]),
			userInfo?[keyBreadcrumbsSerialized] as? BreadcrumbStore.SerializedType
		)
	}
	
}