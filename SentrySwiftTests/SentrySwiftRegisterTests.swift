//
//  SentrySwiftRegisterTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftRegisterTests: XCTestCase {
    
    let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
    let testHelper = SentrySwiftTestHelper()
    
    func testCreateRegister() {
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-BAB8CCF2-2D03-49C4-B7DF-F64BBB1EC291")!
        
        let binaryImagesDicts = crashJSON["binary_images"] as! [[String: AnyObject]]
        let crashDict = crashJSON["crash"] as! [String: AnyObject]
        let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
        
        let binaryImages = binaryImagesDicts.flatMap({BinaryImage(appleCrashBinaryImagesDict: $0)})
        
        var threads = threadDicts.flatMap({ Thread(appleCrashThreadDict: $0, binaryImages: binaryImages) })
        
        var thread = threads[0].serialized as [String: AnyType]
        var stacktrace = thread["stacktrace"] as! [String: AnyType]
        XCTAssertNil(stacktrace["registers"])
        
        var thread1 = threads[1].serialized as [String: AnyType]
        var stacktrace1 = thread1["stacktrace"] as! [String: AnyType]
        var register1 = stacktrace1["registers"] as! [String: String]
        XCTAssertEqual(register1["r8"], "0x3f")
    }
    
}
