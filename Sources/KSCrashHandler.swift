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
		crashHandler = KSCrashHandler(client: self)
	}
}

private typealias CrashDictionary = [String: Any]

private let keyUser = "user"
private let keyEventTags = "event_tags"
private let keyEventExtra = "event_extra"
private let keyBreadcrumbsSerialized = "breadcrumbs_serialized"
private let keyReleaseVersion = "releaseVersion_serialized"


/// A class to report crashes to Sentry built upon KSCrash
internal class KSCrashHandler: CrashHandler {

	// MARK: - Attributes

	private var installation: KSCrashSentryInstallation
	
	private var lock = NSObject()
	private var isInstalled = false

	// MARK: - EventProperties

	internal var releaseVersion: String? {
		didSet { updateUserInfo() }
	}
	internal var tags: EventTags = [:] {
		didSet { updateUserInfo() }
	}
	internal var extra: EventExtra = [:] {
		didSet { updateUserInfo() }
	}
	internal var user: User? {
		didSet { updateUserInfo() }
	}

	required init(client: SentryClient) {
		installation = KSCrashSentryInstallation(client: client)
	}

	// MARK: - CrashHandler

	internal var breadcrumbsSerialized: BreadcrumbStore.SerializedType? {
		didSet { updateUserInfo() }
	}

	/*
	Starts the crash reporting and sends any previously saved crash reports
	- Parameter createdEvent: A closure that passes in a created event
	*/
	internal func startCrashReporting() {
		// Sychrnoizes this function
		objc_sync_enter(lock)
		defer { objc_sync_exit(lock) }

		// Return out if already installed
		if isInstalled { return }
		isInstalled = true
		
		// Install
		installation.install()

		// Maps KSCrash reports in `Events`
		installation.sendAllReports() { (filteredReports, completed, error) -> Void in
			SentryLog.Debug.log(message: "Sent \(filteredReports?.count) report(s)")
		}
	}


	// MARK: - Private Helpers

	private func updateUserInfo() {
		var userInfo = CrashDictionary()
		userInfo[keyEventTags] = tags
		userInfo[keyEventExtra] = extra
		userInfo[keyReleaseVersion] = releaseVersion

		if let user = user?.serialized {
			userInfo[keyUser] = user
		}

		if let breadcrumbsSerialized = breadcrumbsSerialized {
			userInfo[keyBreadcrumbsSerialized] = breadcrumbsSerialized
		}

		KSCrash.sharedInstance().userInfo = userInfo
	}

}

private class KSCrashSentryInstallation: KSCrashInstallation {
	
	private let client: SentryClient
	
	init(client: SentryClient) {
		self.client = client
		super.init(requiredProperties: [])
	}
	
	override func sink() -> KSCrashReportFilter! {
		return KSCrashReportSinkSentry(client: client)
	}
	
}

private class KSCrashReportSinkSentry: NSObject, KSCrashReportFilter {
	
	private let client: SentryClient
	
	init(client: SentryClient) {
		self.client = client
		super.init()
	}
	
	@objc func filterReports(_ reports: [Any]!, onCompletion: KSCrashReportFilterCompletion!) {
		
		// Mapping reports
		let events: [Event] = reports?
			.flatMap({$0 as? CrashDictionary})
			.map({mapReportToEvent(report: $0)}) ?? []
		
		// Sends events recursively
		sendEvent(reports: reports, events: events, success: true, onCompletion: onCompletion)
	}
	
	private func sendEvent(reports: [Any]!, events allEvents: [Event], success: Bool, onCompletion: KSCrashReportFilterCompletion!) {
		var events = allEvents
		
		// Complete when no more
		guard let event = events.popLast() else {
			onCompletion(reports, success, nil)
			return
		}
		
        // Send event
        client.captureEvent(event: event, useClientProperties: true) { [weak self] (eventSuccess) -> Void in
            self?.sendEvent(reports: reports, events: events, success: success && eventSuccess, onCompletion: onCompletion)
        }
	}
	
	private func mapReportToEvent(report: CrashDictionary) -> Event {
		SentryLog.Debug.log(message: "Found report: \(report)")

		// Extract crash timestamp
        var date: Date?
		let timestamp: Date = {
			if let timestampStr = (report["report"] as? [String: Any])?["timestamp"] as? String {
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
				dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
				dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0) as TimeZone!
				date = dateFormatter.date(from: timestampStr)
            }
            if let date = date {
                return date
            } else {
                return Date()
            }
		}()

		// Populate user info
		let userInfo = self.parseUserInfo(userInfo: report["user"] as? CrashDictionary)

		// Generate Apple crash report
		let appleCrashReport: AppleCrashReport? = {
			guard let
				crash = report["crash"] as? [String: Any],
				let binaryImages = report["binary_images"] as? [[String: Any]],
				let system = report["system"] as? [String: Any] else {
					return nil
				}
			return AppleCrashReport(crash: crash, binaryImages: binaryImages, system: system)
		}()

		/// Generate event to sent up to API
		/// Sends a blank message because server does stuff
		let event = Event.build(message: "") {
			$0.level = .fatal
			$0.timestamp = timestamp
			$0.tags = userInfo.tags ?? [:]
			$0.extra = userInfo.extra ?? [:]
			$0.user = userInfo.user
			$0.appleCrashReport = appleCrashReport
			$0.breadcrumbsSerialized = userInfo.breadcrumbsSerialized
			$0.releaseVersion = userInfo.releaseVersion
		}
		
		return event
	}
	
	private func parseUserInfo(userInfo: CrashDictionary?) -> (tags: EventTags?, extra: EventExtra?, user: User?, breadcrumbsSerialized: BreadcrumbStore.SerializedType?, releaseVersion:String?) {
		return (
			userInfo?[keyEventTags] as? EventTags,
			userInfo?[keyEventExtra] as? EventExtra,
			User(dictionary: userInfo?[keyUser] as? [String: Any]),
			userInfo?[keyBreadcrumbsSerialized] as? BreadcrumbStore.SerializedType,
			userInfo?[keyReleaseVersion] as? String
		)
	}
	
}
