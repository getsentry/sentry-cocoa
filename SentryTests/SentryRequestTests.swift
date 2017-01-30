//
//  SentrySwiftRequestTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 15/11/16.
//
//

import XCTest
@testable import Sentry

class SentrySwiftRequestTests: XCTestCase {
    
    let client = SentrySwiftTestHelper.sentryMockClient
    let frame = Frame(fileName: "a", function: "b", line: 1)

    func testExample() {
        let event = SentrySwiftTestHelper.demoFatalEvent
        client.sendEvent(event) { success in
            XCTAssertTrue(success)
        }
    }

    #if swift(>=3.0)
    func testRealRequest() {
        let client = SentrySwiftTestHelper.sentryRealClient
        let event = SentrySwiftTestHelper.demoFatalEvent
        let asyncExpectation = expectation(description: "testRealRequest")
        client.sendEvent(event) { success in
            XCTAssertFalse(success)
            asyncExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
        }
    }
    
    func testRequestQueue() {
        SentryClient.logLevel = .Debug
        let client = SentrySwiftTestHelper.sentryRealClient
        XCTAssertTrue(client.requestManager.isReady)
        let asyncExpectation = expectation(description: "testRequestQueue")
        for i in 1...10 {
            client.captureMessage("TEST \(i)")
        }
        let event = SentrySwiftTestHelper.demoFatalEvent

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            asyncExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
            XCTAssertFalse(client.requestManager.isReady)
        }
    }
    
    func testRequestSavedEvent() {
        let client = SentrySwiftTestHelper.sentryMockClient
        for event in client.savedEvents(since: (Date().timeIntervalSince1970 + 1000)) {
            event.deleteEvent()
        }
        let event = SentrySwiftTestHelper.demoFatalEvent
        client.saveEvent(event)
        let asyncExpectation = expectation(description: "testRequestSavedEvent")
        client.sendEvent(client.savedEvents(since: (Date().timeIntervalSince1970 + 100))[0]) { success in
            XCTAssertTrue(success)
            asyncExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
            for event in client.savedEvents(since: (Date().timeIntervalSince1970 + 1000)) {
                event.deleteEvent()
            }
        }
    }
    #endif
    
}
