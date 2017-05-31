//
//  SentrySwiftTests.swift
//  Sentry
//
//  Created by Daniel Griesser on 31/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

@testable import Sentry
import XCTest

class SentrySwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Client.shared = try? Client(dsn: "https://username:password@app.getsentry.com/12345")
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
        Client.shared = try? Client(dsn: "https://username:password@app.getsentry.com/12345")
        XCTAssertThrowsError(try Client.shared?.startCrashHandler())
    }
    
    func testSendEvent() {
        let event2 = Event(level: .debug)
        event2.extra = ["a": "b" as NSSecureCoding]
        XCTAssertNotNil(event2.serialize())
    }
    
}
