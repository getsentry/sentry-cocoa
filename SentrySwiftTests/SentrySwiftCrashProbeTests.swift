//
//  SentrySwiftCrashProbeTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 05/11/16.
//
//


import XCTest
@testable import SentrySwift

class SentrySwiftCrashProbeTests: XCTestCase {
    
    let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
    let testHelper = SentrySwiftTestHelper()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCrashprobe() {
        let crashJSON = testHelper.readIOSJSONCrashFile("CrashProbeiOS-CrashReport-3CCB10D2-F43D-45CB-8CB8-71A488F8E480")!
        
        let binaryImagesDicts = crashJSON["binary_images"] as! [[String: AnyObject]]
        let crashDict = crashJSON["crash"] as! [String: AnyObject]
        let errorDict = crashDict["error"] as! [String: AnyObject]
        let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
        
    }


}
