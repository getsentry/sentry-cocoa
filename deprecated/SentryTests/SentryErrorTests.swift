//
//  SentrySwiftErrorTests.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 25.05.16.
//
//

import XCTest
@testable import Sentry

class SentrySwiftErrorTests: XCTestCase {
    let client = SentrySwiftTestHelper.sentryMockClient
    let frame = Frame(fileName: "a", function: "b", line: 1)

    func testSimpleError() {
        let domain = "testDomain"
        let code = 123
        let error = NSError(domain: domain, code: code, userInfo: nil)

		let event = Event(error: error, frame: frame)

        XCTAssertEqual(event.message, "\(domain).\(code) in \(frame.culprit)")
        XCTAssertTrue(event.extra["user_info"] is [String: AnyObject])
        XCTAssert((event.extra["user_info"] as! [String: AnyObject]) == [:])
        XCTAssertEqual(event.culprit, frame.culprit)
        XCTAssert(event.stacktrace?.frames.first == frame)
        XCTAssertEqual(event.exceptions!, [Exception(value: "\(error.domain) (\(error.code))", type: error.domain)])
    }

    func testErrorWithUserInfo() {
        let domain = "testDomain"
        let code = 123
		let userInfo: [String: AnyType] = [
            NSLocalizedDescriptionKey: "I am error",
            NSUnderlyingErrorKey: NSError(domain: "foo", code: -42, userInfo: nil),
            "some key": [NSURL(string: "https://example.com")!, 10]
        ]
        let error = NSError(domain: domain, code: code, userInfo: userInfo)

		let event = Event(error: error, frame: frame)

		let expectedUserInfo: [String: AnyType] = [
            NSLocalizedDescriptionKey: "I am error",
            NSUnderlyingErrorKey: [
                "domain": "foo",
                "code": -42,
                "user_info": [:]
            ],
            "some key": ["https://example.com", 10]
        ]
        XCTAssert((event.extra["user_info"] as! [String: AnyObject]) == expectedUserInfo)
		
		#if swift(>=3.0)
			XCTAssertTrue(JSONSerialization.isValidJSONObject(event.serialized) )
		#else
			XCTAssertTrue(NSJSONSerialization.isValidJSONObject(event.serialized) )
		#endif
    }
}
