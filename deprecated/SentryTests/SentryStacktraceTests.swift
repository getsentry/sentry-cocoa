//
//  SentrySwiftSourceLocationTests.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 25.05.16.
//
//

import XCTest
@testable import Sentry

class SentrySwiftSourceLocationTests: XCTestCase {

	let frame = Frame(fileName: "please", function: "this", line: 7357)

    func testCulprit() {
        XCTAssertEqual(frame.culprit, "please:7357 this")
        
        let frame2 = Frame(fileName: nil, function: "this", line: 7357)
        XCTAssertNil(frame2.culprit)
    }

    func testStacktrace() {
		let expectedFrame: [String: AnyType] = [
			"filename": "please",
			"lineno": 7357,
			"function": "this"
        ]
        XCTAssert(frame.serialized == expectedFrame)
    }

    func testTruncatesPath() {
		let frame = Frame(fileName: "/absolute/path/to/something.spl", function: "a", line: 1)
        XCTAssertEqual(frame.culprit, "/absolute/path/to/something.spl:1 a")
    }

    func testSourceLocationMerge() {
		let error = NSError(domain: "Some Domain", code: 1235, userInfo: nil)
		let event = Event(error: error, frame: frame)
        
        XCTAssertEqual(event.culprit, frame.culprit)
        XCTAssert(event.stacktrace?.frames.first == frame)
    }

}
