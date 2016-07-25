//
//  SentrySwiftCrashTests.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/25/16.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftCrashTests: XCTestCase {
	
	let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
	
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func testCrashAbort() {
		let crashJSON = readJSONCrashFile("Abort")!
		let crashDict = crashJSON["crash"] as! [String: AnyObject]
		let threadDicts = crashDict["threads"] as! [[String: AnyObject]]
		
		let threads = threadDicts.flatMap({Thread(threadCrashDict: $0)})
		
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
	}

	// MARK: Private

	typealias JSONCrashFile = [String: AnyObject]
	private func readJSONCrashFile(name: String) -> JSONCrashFile? {
		
		let bundle = NSBundle(forClass: self.dynamicType)
		guard let path = bundle.pathForResource(name, ofType: "json") else {
			return nil
		}
		do {
			let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
			let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
			return json as? JSONCrashFile
		} catch {
			return nil
		}
	}
}