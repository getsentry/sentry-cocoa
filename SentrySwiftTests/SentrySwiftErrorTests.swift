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
    let location = SentryClient.SourceLocation(file: "a", line: 1, function: "b")

    func testSimpleError() {
        let domain = "testDomain"
        let code = 123
        let error = NSError(domain: domain, code: code, userInfo: nil)

        let event = client.eventFor(error: error, location: location)

        assert(event.message == "\(domain).\(code) in \(location.culprit)")
        assert(event.extra!["user_info"] is [String: AnyObject])
        assert((event.extra!["user_info"] as! [String: AnyObject]) == [:])
        assert(event.culprit == location.culprit)
        assert(event.stackTrace! == location.stackTrace)
        assert(event.exception! == [Exception(type: error.domain, value: "\(error.domain) (\(error.code))")])
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

        let event = client.eventFor(error: error, location: location)

        let expectedUserInfo = [
            NSLocalizedDescriptionKey: "I am error",
            NSUnderlyingErrorKey: [
                "domain": "foo",
                "code": -42,
                "user_info": [:]
            ],
            "some key": ["https://example.com", 10]
        ]
        assert((event.extra!["user_info"] as! [String: AnyObject]) == expectedUserInfo)
    }
}
