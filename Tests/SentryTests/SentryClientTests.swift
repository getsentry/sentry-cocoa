//
//  SentryClientTests.swift
//  SentryTests
//
//  Created by Philipp Hofmann on 07.04.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

class SentryClientTest: XCTestCase {
    
    private var client: Client!
    private var transport: TestTransport!
    
    private let dsn = "https://username:password@app.getsentry.com/12345"
    
    override func setUp() {
        super.setUp()
        
        transport = TestTransport()
        
        do {
            let options = try Options(dict: ["dsn": dsn,
                                             "transport": transport])
            client = Client(options: options)
        } catch {
            XCTFail("Options could not be created")
        }
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }
    
    
    func testInitCallsSendAllStoredEvents() {
        XCTAssertEqual(1, transport.sendAllStoredEventsInvocations)
    }
    
}
