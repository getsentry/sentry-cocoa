//
//  SentrySwiftErrorTests.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 25.05.16.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftErrorTests: XCTestCase {
    let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
    let frame = Frame(file: "a", function: "b", line: 1)

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
        let userInfo = [
            NSLocalizedDescriptionKey: "I am error",
            NSUnderlyingErrorKey: NSError(domain: "foo", code: -42, userInfo: nil),
            "some key": [NSURL(string: "https://example.com")!, 10]
        ]
        let error = NSError(domain: domain, code: code, userInfo: userInfo)

		let event = Event(error: error, frame: frame)

        let expectedUserInfo = [
            NSLocalizedDescriptionKey: "I am error",
            NSUnderlyingErrorKey: [
                "domain": "foo",
                "code": -42,
                "user_info": [:]
            ],
            "some key": ["https://example.com", 10]
        ]
        XCTAssert((event.extra["user_info"] as! [String: AnyObject]) == expectedUserInfo)
    }
}
