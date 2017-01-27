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

class SentryClientTests: XCTestCase {
	
    var client = SentrySwiftTestHelper.sentryMockClient
	
    #if swift(>=3.0)
	func test_setReleaseVersion_crashHandlerIsPresent_releaseVersionIsPassedOnToCrashHandler() {
		let crashHandler = TestCrashHandler(client: client)
		client.crashHandler = crashHandler

		let releaseVersion = "1.2.3"
		client.releaseVersion = releaseVersion
        let buildNumber = "321"
        client.buildNumber = buildNumber

		XCTAssertEqual(releaseVersion, client.releaseVersion)
		XCTAssertEqual(releaseVersion, crashHandler.releaseVersion)
        
        XCTAssertEqual(buildNumber, client.buildNumber)
        XCTAssertEqual(buildNumber, crashHandler.buildNumber)
	}

	func test_setReleaseVersion_crashHandlerIsNotSet_releaseVersionIsOnlySetOnClient() {
		let releaseVersion = "1.2.3"
		client.releaseVersion = releaseVersion

        let buildNumber = "321"
        client.buildNumber = buildNumber

		XCTAssertEqual(releaseVersion, client.releaseVersion)
        XCTAssertEqual(buildNumber, client.buildNumber)
		XCTAssertNil(client.crashHandler)
	}
    #endif
}
