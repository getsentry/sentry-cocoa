//
//  SentryTransportInitializerTests.swift
//  SentryTests
//
//  Created by Philipp Hofmann on 08.04.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

import XCTest

class SentryTransportInitializerTests: XCTestCase {

    func testDefault() throws {
        let options =  try Options(dict: ["dsn": TestConstants.dsn])
        let result = TransportInitializer.initTransport(options)
        
        XCTAssertTrue( result.isKind(of: SentryHttpTransport.self))
    }
    
    func testCustom() throws {
        let transport = TestTransport()
        let options = try Options(dict: ["dsn": TestConstants.dsn, "transport": transport])
        let result = TransportInitializer.initTransport(options)
        
        XCTAssertTrue( result.isKind(of: TestTransport.self))
    }
}
