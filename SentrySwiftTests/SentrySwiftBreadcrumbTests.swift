//
//  SentrySwiftBreadcrumbTests.swift
//  SentrySwift
//
//  Created by Josh Holtz on 3/25/16.
//
//

import XCTest
import SentrySwift
@testable import SentrySwift

class SentrySwiftBreadcrumbTests: XCTestCase {
	
	let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
	
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func testGeneralCrumbs() {
		let dateString = "2011-05-02T17:41:36"
		let date = NSDate.fromISO8601(dateString)!
		
		let crumb = Breadcrumb(category: "test", timestamp: date, type: "some_type", data: ["foo": "bar"])
		
		let serialized = crumb.serialized
		
		XCTAssertEqual(serialized["type"] as? String, "some_type")
		XCTAssertEqual(serialized["timestamp"] as? String, dateString)
	}
	
	func testBreadcrumbStorage() {
		
		let store = BreadcrumbStore()
		store.maxCrumbs = 3
		
		let test1 = Breadcrumb(category: "test", message: "Test 1")
		let test2 = Breadcrumb(category: "test", message: "Test 2")
		let test3 = Breadcrumb(category: "test", message: "Test 3")
		let test4 = Breadcrumb(category: "test", message: "Test 4")
		
		store.add(test1)
		XCTAssertEqual(store.crumbs.count, 1)
		XCTAssertEqual(store.crumbs, [test1])
		
		store.add(test2)
		XCTAssertEqual(store.crumbs.count, 2)
		XCTAssertEqual(store.crumbs, [test1, test2])
		
		store.add(test3)
		XCTAssertEqual(store.crumbs.count, 3)
		XCTAssertEqual(store.crumbs, [test1, test2, test3])
		
		store.add(test4)
		XCTAssertEqual(store.crumbs.count, 3)
		XCTAssertEqual(store.crumbs, [test2, test3, test4])
	}
    
    func testBreadcrumbStorageClear() {
        let store = BreadcrumbStore()
        store.maxCrumbs = 5
        
        for _ in 1...store.maxCrumbs {
            store.add(Breadcrumb(category: "test", message: "Test 1"))
        }
        
        store.clear()
        XCTAssertEqual(store.crumbs.count, 0)
    }
    
    func testBreadcrumbStorageSerialize() {
        let store = BreadcrumbStore()
        store.maxCrumbs = 5
        
        for i in 1...store.maxCrumbs {
            store.add(Breadcrumb(category: "test\(i)", message: "Test 1"))
        }

        XCTAssertEqual("\((store.serialized.last?["category"])!)", "test5")
    }
    
    func testBreadcrumbStorageLimits() {
        let store = BreadcrumbStore()
        store.maxCrumbs = 50000
        
        for _ in 1...store.maxCrumbs {
            store.add(Breadcrumb(category: "test", message: "Test 1"))
        }
        
        XCTAssertEqual(store.crumbs.count, 50000)
        
        for _ in 1...store.maxCrumbs {
            store.add(Breadcrumb(category: "test", message: "Test 2"))
        }
        
        XCTAssertEqual(store.crumbs.count, 50000)
    }

}
