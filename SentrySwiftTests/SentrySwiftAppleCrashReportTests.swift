//
//  SentrySwiftAppleCrashReportTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 15/11/16.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftAppleCrashReportTests: XCTestCase {
    
    let appleCrashReport = AppleCrashReport(crash: ["test": "1" as AnyObject], binaryImages: [["test": "2" as AnyObject]],
        system: ["test": "3" as AnyObject])
    
    func testAppleCrashReport() {
        let expectedFrame: [String: AnyType] = [
            "crash": ["test": "1"],
            "binary_images": [["test": "2"]],
            "system": ["test": "3"]
        ]
        
        XCTAssert(appleCrashReport.serialized == expectedFrame)
    }
    
}
