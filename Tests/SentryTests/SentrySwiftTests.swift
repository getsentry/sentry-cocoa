//
//  SentrySwiftTests.swift
//  Sentry
//
//  Created by Daniel Griesser on 31/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

@testable import Sentry
import XCTest
// 0x7fc9a4920b40
class SentrySwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        let fileManager = try! SentryFileManager(dsn: SentryDsn(string: "https://username:password@app.getsentry.com/12345"))
        fileManager.deleteAllStoredEvents()
        fileManager.deleteAllStoredBreadcrumbs()
        fileManager.deleteAllFolders()
        SentrySDK.start(options: ["dsn": "https://username:password@app.getsentry.com/12345"])
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
    
    func testOptions() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345"])

        let client = try? Client(options: options)
        XCTAssertNotNil(client)
    }
    
    func testDisabled() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345", "enabled": false])

        let client = try? Client(options: options)
        XCTAssertNotNil(client)
        
        client!.beforeSendRequest = { request in
            XCTAssertTrue(false)
        }
        
        let event2 = Event(level: .debug)
        let scope = Sentry.Scope(options: client!.options)
        scope.extra = ["a": "b"]
        client!.send(event: event2, scope: scope)
    }
    
    func testEnabled() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345", "enabled": true])

        let client = try? Client(options: options)
        XCTAssertNotNil(client)
        
        client!.beforeSendRequest = { request in
            XCTAssertTrue(true)
        }
        
        let event2 = Event(level: .debug)
        let scope = Sentry.Scope(options: client!.options)
        scope.extra = ["a": "b"]
        client!.send(event: event2, scope: scope) { (error) in
            XCTAssertNil(error)
        }
    }
    
    func testFunctionCalls() {
        let event = Event(level: .debug)
        event.message = "Test Message"
        event.environment = "staging"
        let scope = Sentry.Scope(options: SentrySDK.currentHub().getClient()!.options)
        scope.extra = ["ios": true]
        XCTAssertNotNil(event.serialize())
        SentrySDK.currentHub().getClient()!.send(event: event, scope: scope)

        let event2 = Event(level: .debug)
        let scope2 = Sentry.Scope(options: SentrySDK.currentHub().getClient()!.options)
        scope2.extra = ["a": "b"]
        XCTAssertNotNil(event2.serialize())
        
        SentrySDK.currentHub().getClient()!.beforeSerializeEvent = { event in
            event.extra = ["b": "c"]
        }
        
        SentrySDK.currentHub().getClient()!.send(event: event2, scope: scope) { (error) in
            XCTAssertNil(error)
        }
        
        Client.logLevel = .debug
        SentrySDK.currentHub().getClient()!.clearContext()
        // TODO(fetzig): check if this is the intended way to do this
//        SentrySDK.currentHub().configureScope { (scope) in
//            scope.breadcrumbs.maxBreadcrumbs = 100
//            scope.breadcrumbs.add(Breadcrumb(level: .info, category: "test"))
//        }
//        XCTAssertEqual(Client.shared?.breadcrumbs.count(), 1)
//        Client.shared?.enableAutomaticBreadcrumbTracking()
//        let user = User()
//        user.userId = "1234"
//        user.email = "hello@sentry.io"
//        user.extra = ["is_admin": true]
//        Client.shared?.user = user
//
//        Client.shared?.tags = ["iphone": "true"]
//
//        Client.shared?.clearContext()
//
//        Client.shared?.snapshotStacktrace {
//            let event = Event(level: .debug)
//            event.message = "Test Message"
//            Client.shared?.send(event: event)
//        }
//        Client.shared?.beforeSendRequest = { request in
//            request.addValue("my-token", forHTTPHeaderField: "Authorization")
//        }
    }
    
}
