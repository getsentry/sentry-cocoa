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

internal typealias CrashDictionary = [String: AnyType]

internal let keyUser = "user"
internal let keyEventTags = "event_tags"
internal let keyEventExtra = "event_extra"
internal let keyBreadcrumbsSerialized = "breadcrumbs_serialized"
internal let keyReleaseVersion = "releaseVersion_serialized"

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
        installation = KSCrashSentryInstallation(client: client, crashReportConverter: CrashReportConverter())
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
		#if swift(>=3.0)
			installation.sendAllReports() { (filteredReports, completed, error) -> Void in
				SentryLog.Debug.log("Sent \(filteredReports?.count) report(s)")
			}
		#else
			installation.sendAllReportsWithCompletion() { (filteredReports, completed, error) -> Void in
				SentryLog.Debug.log("Sent \(filteredReports.count) report(s)")
			}
		#endif
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
    private let crashReportConverter: CrashReportConverter
    
    init(client: SentryClient, crashReportConverter: CrashReportConverter) {
        self.client = client
        self.crashReportConverter = crashReportConverter
		super.init(requiredProperties: [])
	}
	
	override func sink() -> KSCrashReportFilter! {
        return KSCrashReportSinkSentry(client: client, crashReportConverter: crashReportConverter)
	}
	
}

private class KSCrashReportSinkSentry: NSObject, KSCrashReportFilter {
	
	private let client: SentryClient
    private let crashReportConverter: CrashReportConverter
	
	init(client: SentryClient, crashReportConverter: CrashReportConverter) {
		self.client = client
        self.crashReportConverter = crashReportConverter
		super.init()
	}
	
	@objc func filterReports(_ reports: [AnyType]!, onCompletion: KSCrashReportFilterCompletion!) {
		
		// Mapping reports
		let events: [Event] = reports?
			.flatMap({$0 as? CrashDictionary})
			.flatMap({crashReportConverter.mapReportToEvent($0)}) ?? []
		
		// Sends events recursively
		sendEvent(reports, events: events, success: true, onCompletion: onCompletion)
	}
	
    // TODO: move to seperate class
	private func sendEvent(_ reports: [AnyType]!, events allEvents: [Event], success: Bool, onCompletion: KSCrashReportFilterCompletion!) {
		var events = allEvents
		
		// Complete when no more
		guard let event = events.popLast() else {
			onCompletion(reports, success, nil)
			return
		}
		
		// Send event
		client.captureEvent(event, useClientProperties: true) { [weak self] eventSuccess in
			self?.sendEvent(reports, events: events, success: success && eventSuccess, onCompletion: onCompletion)
		}
	}
	
}
