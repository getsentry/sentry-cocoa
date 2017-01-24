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
//        "registers": {
//            "basic": {
//                "rax": 4411746352,
//                "rbx": 105553116331584,
//                "rcx": 12,
//                "rdx": 140734683554072,
//                "rdi": 105553116331584,
//                "rsi": 4411757873,
//                "rbp": 140734683554160,
//                "rsp": 140734683554160,
//                "r8": 63,
//                "r9": 105553116331584,
//                "r10": 1,
//                "r11": 4411746512,
//                "r12": 4411224042,
//                "r13": 105553116601264,
//                "r14": 4443646656,
//                "r15": 140721562654368,
//                "rip": 4411746539,
//                "rflags": 66118,
//                "cs": 43,
//                "fs": 0,
//                "gs": 0
//            },
//            "exception": {
//                "trapno": 14,
//                "err": 7,
//                "faultvaddr": 4411746352
//            }
//        },
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-BAB8CCF2-2D03-49C4-B7DF-F64BBB1EC291")!
        
        let binaryImagesDicts = crashJSON["binary_images"] as! [[String: AnyObject]]
        let crashDict = crashJSON["crash"] as! [String: AnyObject]
        let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
        
        let binaryImages = binaryImagesDicts.flatMap({BinaryImage(appleCrashBinaryImagesDict: $0)})
        
        var threads = threadDicts.flatMap({ Thread(appleCrashThreadDict: $0, binaryImages: binaryImages) })
        
    }
    
}
