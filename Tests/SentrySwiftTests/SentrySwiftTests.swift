//
//  SentrySwiftTests.swift
//  SentrySwiftTests
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

@testable import SentrySwift
import XCTest

class SentrySwiftTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testWrongDsn() {
        XCTAssertThrowsError(try Client(dsn: "http://sentry.io"))
    }
    
    func testCorrectDsn() {
        let client = try? Client(dsn: "https://username:password@app.getsentry.com/12345")
        XCTAssertNotNil(client)
    }
    
    func testStartCrashHandler() {
        Client.sharedClient = try? Client(dsn: "https://username:password@app.getsentry.com/12345")
        XCTAssertThrowsError(try Client.sharedClient?.startCrashHandler())
    }

}
