//
//  SwiftSentryReactNativeCrashTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 14/12/2016.
//
//

import XCTest
import KSCrash
@testable import SentrySwift

class SwiftSentryReactNativeCrashTests: XCTestCase {
    
    let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
    let testHelper = SentrySwiftTestHelper()
    
    func testCreateEventWithStacktrace() {
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "ReactNativeExample-report-00700e33b1400000")!
        
        let event = CrashReportConverter.convertReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertFalse((event?.exceptions?.first?.userReported)!)
    }
    
}
