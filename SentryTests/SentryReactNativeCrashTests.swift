//
//  SentrySwiftReactNativeCrashTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 14/12/2016.
//
//

import XCTest
import KSCrash
@testable import Sentry

class SentrySwiftReactNativeCrashTests: XCTestCase {
    
    let client = SentrySwiftTestHelper.sentryMockClient
    let testHelper = SentrySwiftTestHelper()
    
    func testCreateEventWithStacktrace() {
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "ReactNativeExample-report-00700e33b1400000")!
        
        let event = CrashReportConverter.convertReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertFalse((event?.exceptions?.first?.userReported)!)
    }
    
    func testSanitizeReactReleaseStacktrace() {
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "ReactNativeExample-report-00700e33b1400000")!
        
        let event = CrashReportConverter.convertReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.threads?.last?.name, "React Native")
        XCTAssertEqual(event?.threads?.last?.stacktrace?.frames.first?.fileName, "/main.jsbundle")
        
        let crashedThreads = event?.threads?.filter({ $0.crashed ?? true })
        XCTAssertEqual(crashedThreads?.count, 1)
        XCTAssertEqual(crashedThreads?.first?.name, "React Native")
    }
    
    func testSanitizeReactDebugStacktrace() {
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "ReactNativeExample-report-00700e33b1400000-debug")!
        
        let event = CrashReportConverter.convertReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.threads?.last?.name, "React Native")
        XCTAssertEqual(event?.threads?.last?.stacktrace?.frames.first?.fileName, "/index.ios.bundle")
    }
}
