//
//  SentrySwiftSourceLocationTests.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 25.05.16.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftSourceLocationTests: XCTestCase {

    let loc = SentryClient.SourceLocation(file: "please", line: 7357, function: "this")

    func testCulprit() {
        assert(loc.culprit == "please:7357 this")
    }

    func testStacktrace() {
        let expectedTrace = [
            "frames": [
                [
                    "filename": "please",
                    "lineno": 7357,
                    "function": "this",
                ]
            ]
        ]
        assert(loc.stackTrace == expectedTrace)
    }

    func testTruncatesPath() {
        let loc = SentryClient.SourceLocation(file: "/absolute/path/to/something.spl", line: 1, function: "a")
        assert(loc.culprit == "something.spl:1 a")
    }

    func testSourceLocationMerge() {
        let event = Event("hi there")
        event.mergeSourceLocation(loc)
        assert(event.culprit == loc.culprit)
        assert(event.stackTrace! == loc.stackTrace)
    }

}