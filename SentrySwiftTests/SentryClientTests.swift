//
//  SentryClientTests.swift
//  SentrySwift
//
//  Created by Benjamin Horsleben on 16/06/16.
//
//

import Foundation
import XCTest
@testable import SentrySwift

class TestCrashHandler: CrashHandler {
	required init(client: SentryClient) {
	}

	var crashReportingHasStarted = false
	func startCrashReporting() {
		crashReportingHasStarted = true
	}

    func sendAllReports() {
        
    }
    
	var breadcrumbsSerialized: BreadcrumbStore.SerializedType?
	var releaseVersion: String?
	var tags: EventTags = [:]
	var extra: EventExtra = [:]
	var user: User?
}
//
//class TestableSentryClient: SentryClient {
//	var dataToSend:[(data:NSData, callback: SentryEndpointRequestFinished?)] = []
//	override func sendEvent(_ event: SavedEvent, finished: SentryEndpointRequestFinished? = nil) {
//		// Do nothing. The original sends data to the server
//
//		dataToSend.append((event.data, finished))
//	}
//}

class SentryClientTests: XCTestCase {
	var client:SentryClient!
	override func setUp() {
		super.setUp()

		let dsn = DSN(url: NSURL(), publicKey: nil, secretKey: nil, projectID: "some project")
		client = SentryClient(dsn: dsn)
	}
    #if swift(>=3.0)
	func test_setReleaseVersion_crashHandlerIsPresent_releaseVersionIsPassedOnToCrashHandler() {
		let crashHandler = TestCrashHandler(client: client)
		client.crashHandler = crashHandler

		let releaseVersion = "1.2.3"
		client.releaseVersion = releaseVersion

		XCTAssertEqual(releaseVersion, client.releaseVersion)
		XCTAssertEqual(releaseVersion, crashHandler.releaseVersion)
	}

	func test_setReleaseVersion_crashHandlerIsNotSet_releaseVersionIsOnlySetOnClient() {
		let releaseVersion = "1.2.3"
		client.releaseVersion = releaseVersion

		XCTAssertEqual(releaseVersion, client.releaseVersion)
		XCTAssertNil(client.crashHandler)
	}
    #endif
}
