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


/// A class to report crashes to Sentry built upon KSCrash
internal class KSCrashHandler: CrashHandler {
	typealias CrashDictionary = [String: AnyObject]


	// MARK: - Attributes

	private let installation: KSCrash?

	private let keyUser = "user"
	private let keyEventTags = "event_tags"
	private let keyEventExtra = "event_extra"
	private let keyBreadcrumbsSerialized = "breadcrumbs_serialized"


	// MARK: - Initializers

	private init() {
		self.installation = KSCrash.sharedInstance()

		if installation == nil {
			SentryLog.Error.log("There is no KSCrash.shareInstance for some unknown reason")
		}
	}


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
	internal func startCrashReporting(createdEvent: (generatedEvent: Event) -> ()) {

		// Temporarily sets introspect to false due to KSCrash bug
		// -> https://github.com/kstenerud/KSCrash/issues/110
		installation?.introspectMemory = false

		// Maps KSCrash reports in `Events`
		installation?.sendAllReportsWithCompletion() { (filteredReports, completed, error) -> Void in
			for report in filteredReports {
				SentryLog.Debug.log("Found report: \(report)")

				// Make sure report is a dictionary that we can handle
				guard let report = report as? CrashDictionary else {
					SentryLog.Error.log("KSCrash report was not of type [String: AnyObject]")
					return
				}

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


				/*
				* This is probably only temporary so that we can have some unique
				* info for the crash until we can desymbolicate logs on Sentry's API.
				*/
				let exceptionName: String = report["crash"]?["error"]??["mach"]??["exception_name"] as? String ?? "Fatal error"

				let backtrace: [CrashDictionary]? = report["crash"]?["threads"] as? [CrashDictionary]
				let crashedThread: CrashDictionary? = backtrace?.filter { thread in
					guard let crashed = thread["crashed"] as? Bool else { return false }
					return crashed
				}.first

				let contents: [CrashDictionary]? = crashedThread?["backtrace"]?["contents"] as? [CrashDictionary]
				let firstContentName: AnyObject? = contents?.first?["symbol_name"]

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
				createdEvent(generatedEvent: event)
			}
		}

		installation?.install()
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

		installation?.userInfo = userInfo
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
