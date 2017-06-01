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
        let fileManager = try! SentryFileManager(error: ())
        fileManager.deleteAllStoredEvents()
        fileManager.deleteAllStoredBreadcrumbs()
        fileManager.deleteAllFolders()
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
    
    func testFunctionCalls() {
        let event2 = Event(level: .debug)
        event2.extra = ["a": "b"]
        XCTAssertNotNil(event2.serialize())
        
        Client.shared?.beforeSerializeEvent = { event in
            event.extra = ["b": "c"]
        }
        
        Client.shared?.send(event2) { (error) in
            XCTAssertNil(error)
        }
        Client.logLevel = .debug
        Client.shared?.clearContext()
        // Client.shared?.lastEvent
        Client.shared?.breadcrumbs.add(Breadcrumb(level: .info, category: "test"))
        XCTAssertEqual(Client.shared?.breadcrumbs.count(), 1)
//        Client.shared.s
    }
    
}
