//
//  SentrySwiftCrashTests.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/25/16.
//
//

import XCTest
@testable import Sentry

class SentrySwiftCrashTests: XCTestCase {
	
	let client = SentrySwiftTestHelper.sentryMockClient
	let testHelper = SentrySwiftTestHelper()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
    #if swift(>=3.0)
	func testUInt64ToHex() {
		let hexAddress = MemoryAddress(827844157 as AnyObject?)
		XCTAssertEqual(hexAddress?.asHex(), "0x3157e63d")
        XCTAssertEqual(hexAddress?.asInt(), 827844157)
        
        let hexAddress2 = MemoryAddress(nil)
        XCTAssertNil(hexAddress2)
        XCTAssertNil(hexAddress2?.asHex())
        
        let hexAddress3 = MemoryAddress(String(
            bytes: [0xD8, 0x00] as [UInt8],
            encoding: String.Encoding.utf16BigEndian) as? AnyObject)
        XCTAssertNil(hexAddress3)
        
        let hexAddress4 = MemoryAddress("ö" as? AnyObject)
        XCTAssertNil(hexAddress4)
	}
    #endif
    
    func testCorruptKSCrashReports() {
        XCTAssertNil(CrashReportConverter.convertReportToEvent(testHelper.readJSONCrashFile(name: "Crash-missing-binary-images")!))
        XCTAssertNil(CrashReportConverter.convertReportToEvent(testHelper.readJSONCrashFile(name: "Crash-missing-crash-error")!))
        XCTAssertNil(CrashReportConverter.convertReportToEvent(testHelper.readJSONCrashFile(name: "Crash-missing-crash-threads")!))
        XCTAssertNil(CrashReportConverter.convertReportToEvent(testHelper.readJSONCrashFile(name: "Crash-missing-crash")!))
        let event = CrashReportConverter.convertReportToEvent(testHelper.readJSONCrashFile(name: "Crash-missing-user")!)
        XCTAssertEqual(event!.tags.count, 0)
        XCTAssertEqual(event!.extra.count, 0)
    }
    
    func testCrashSignal() {
		let crashJSON = testHelper.readJSONCrashFile(name: "Abort")!
		let binaryImagesDicts = crashJSON["binary_images"] as! [[String: AnyObject]]
		let crashDict = crashJSON["crash"] as! [String: AnyObject]
		let errorDict = crashDict["error"] as! [String: AnyObject]
		let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
		
		let binaryImages = binaryImagesDicts.flatMap({BinaryImage(appleCrashBinaryImagesDict: $0)})
		
		var threads = threadDicts.flatMap({Thread(appleCrashThreadDict: $0, binaryImages: binaryImages)})
		
		// Test threads
		XCTAssertEqual(threads.count, 8)
		
		let thread0 = threads[0]
		XCTAssertEqual(thread0.id, 0)
		XCTAssertTrue(thread0.crashed!)
		XCTAssertTrue(thread0.current!)
		
		let thread1 = threads[1]
		XCTAssertEqual(thread1.id, 1)
		XCTAssertFalse(thread1.crashed!)
		XCTAssertFalse(thread1.current!)
		
		let thread2 = threads[2]
		XCTAssertEqual(thread2.id, 2)
		XCTAssertFalse(thread2.crashed!)
		XCTAssertFalse(thread2.current!)
		
		let thread3 = threads[3]
		XCTAssertEqual(thread3.id, 3)
		XCTAssertFalse(thread3.crashed!)
		XCTAssertFalse(thread3.current!)
		
		let thread4 = threads[4]
		XCTAssertEqual(thread4.id, 4)
		XCTAssertFalse(thread4.crashed!)
		XCTAssertFalse(thread4.current!)
		XCTAssertEqual(thread4.name, "WebThread")
		
		// Test exception
		let exception = Exception(appleCrashErrorDict: errorDict)
        exception.update(threads: &threads)
		XCTAssertEqual(exception.thread?.id, 0)
		XCTAssertEqual(exception.value, "Signal 6, Code 0")
		XCTAssertEqual(exception.type, "SIGABRT")
	}
	
	func testCrashMach() {
		let crashJSON = testHelper.readJSONCrashFile(name: "StackOverflow")!
		let binaryImagesDicts = crashJSON["binary_images"] as! [[String: AnyObject]]
		let crashDict = crashJSON["crash"] as! [String: AnyObject]
		let errorDict = crashDict["error"] as! [String: AnyObject]
		let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
		
		let binaryImages = binaryImagesDicts.flatMap({BinaryImage(appleCrashBinaryImagesDict: $0)})
		
		var threads = threadDicts.flatMap({Thread(appleCrashThreadDict: $0, binaryImages: binaryImages)})
		
		// Test threads
		XCTAssertEqual(threads.count, 7)
		
		let thread0 = threads[0]
		XCTAssertEqual(thread0.id, 0)
		XCTAssertTrue(thread0.crashed!)
		XCTAssertFalse(thread0.current!)
		
		let thread1 = threads[1]
		XCTAssertEqual(thread1.id, 1)
		XCTAssertFalse(thread1.crashed!)
		XCTAssertFalse(thread1.current!)
		
		let thread2 = threads[2]
		XCTAssertEqual(thread2.id, 2)
		XCTAssertFalse(thread2.crashed!)
		XCTAssertFalse(thread2.current!)
		
		let thread3 = threads[3]
		XCTAssertEqual(thread3.id, 3)
		XCTAssertFalse(thread3.crashed!)
		XCTAssertFalse(thread3.current!)
		XCTAssertEqual(thread3.name, "WebThread")
		
		let thread4 = threads[4]
		XCTAssertEqual(thread4.id, 4)
		XCTAssertFalse(thread4.crashed!)
		XCTAssertFalse(thread4.current!)
		
		let thread5 = threads[5]
		XCTAssertEqual(thread5.id, 5)
		XCTAssertFalse(thread5.crashed!)
		XCTAssertFalse(thread5.current!)
		XCTAssertEqual(thread5.name, "KSCrash Exception Handler (Secondary)")
		
		let thread6 = threads[6]
		XCTAssertEqual(thread6.id, 6)
		XCTAssertFalse(thread6.crashed!)
		XCTAssertTrue(thread6.current!)
		XCTAssertEqual(thread6.name, "KSCrash Exception Handler (Primary)")
		
		// Test exception
        let exception = Exception(appleCrashErrorDict: errorDict)
        exception.update(threads: &threads)
		XCTAssertEqual(exception.thread?.id, 0)
		XCTAssertEqual(exception.value, "Exception 1, Code 1, Subcode 0")
		XCTAssertEqual(exception.type, "EXC_BAD_ACCESS")
	}
	
	func testCrashNSException() {
		let crashJSON = testHelper.readJSONCrashFile(name: "NSException")!
		let binaryImagesDicts = crashJSON["binary_images"] as! [[String: AnyObject]]
		let crashDict = crashJSON["crash"] as! [String: AnyObject]
		let errorDict = crashDict["error"] as! [String: AnyObject]
		let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
		
		let binaryImages = binaryImagesDicts.flatMap({BinaryImage(appleCrashBinaryImagesDict: $0)})
		
		var threads = threadDicts.flatMap({Thread(appleCrashThreadDict: $0, binaryImages: binaryImages)})
		
		// Test threads
		XCTAssertEqual(threads.count, 8)
		
		// Thread 0
		let thread0 = threads[0]
		XCTAssertEqual(thread0.id, 0)
		XCTAssertTrue(thread0.crashed!)
		XCTAssertTrue(thread0.current!)
		
		let thread0Stacktrace = thread0.stacktrace!
		let thread0Frames = thread0Stacktrace.frames
		XCTAssertEqual(thread0Frames.count, 23)
		XCTAssertEqual(thread0Frames[0].instructionAddress, "0x3157e63d")
		XCTAssertEqual(thread0Frames[0].symbolAddress, "0x3157e5dc")
		XCTAssertEqual(thread0Frames[0].imageAddress, "0x314e0000")
        XCTAssertEqual(thread0Frames[0].package, "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
		XCTAssertEqual(thread0Frames[1].instructionAddress, "0x35099c5d")
		XCTAssertEqual(thread0Frames[1].symbolAddress, "0x35099c44")
		XCTAssertEqual(thread0Frames[1].imageAddress, "0x35095000")
        XCTAssertEqual(thread0Frames[1].package, "/Bundle/Application/Something/I/Added/Manually/For/Tests")
		
		// Thread 1
		let thread1 = threads[1]
		XCTAssertEqual(thread1.id, 1)
		XCTAssertFalse(thread1.crashed!)
		XCTAssertFalse(thread1.current!)
		
		let thread2 = threads[2]
		XCTAssertEqual(thread2.id, 2)
		XCTAssertFalse(thread2.crashed!)
		XCTAssertFalse(thread2.current!)
		
		let thread3 = threads[3]
		XCTAssertEqual(thread3.id, 3)
		XCTAssertFalse(thread3.crashed!)
		XCTAssertFalse(thread3.current!)
		
		let thread4 = threads[4]
		XCTAssertEqual(thread4.id, 4)
		XCTAssertFalse(thread4.crashed!)
		XCTAssertFalse(thread4.current!)
		XCTAssertEqual(thread4.name, "WebThread")
		
		// Test exception
		let exception = Exception(appleCrashErrorDict: errorDict)
        exception.update(threads: &threads)
		XCTAssertEqual(exception.thread?.id, 0)
		XCTAssertEqual(exception.value, "-[__NSArrayI objectForKey:]: unrecognized selector sent to instance 0x1e59bc50")
		XCTAssertEqual(exception.type, "NSInvalidArgumentException")
	}

}
