//
//  SentrySwiftRequestTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 15/11/16.
//
//

import XCTest
@testable import SentrySwift

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
        #if swift(>=3.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                asyncExpectation.fulfill()
            }
        #endif
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
            XCTAssertFalse(client.requestManager.isReady)
        }
    }
    #endif
    
}
