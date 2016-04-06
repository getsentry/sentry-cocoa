//
//  SentrySwiftCrashTests.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/25/16.
//
//

import XCTest
import SentrySwift

class SentrySwiftCrashTests: XCTestCase {
	
	let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
	
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func testCrashAbort() {
		_ = readJSONCrashFile("Abort")
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