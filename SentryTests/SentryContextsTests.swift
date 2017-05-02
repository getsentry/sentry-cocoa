//
//  SentrySwiftContextsTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 19/12/2016.
//
//

import XCTest
@testable import Sentry
@testable import SentryKSCrash

class SentrySwiftContextsTests: XCTestCase {

    #if swift(>=3.0)
    // Note this test only succeeds when all tests run because otherwise it will not have the whole system info
    func testContext() {
        let context = Contexts().serialized
        let os = context["os"] as? SerializedTypeDictionary
        let device = context["device"] as? SerializedTypeDictionary
        let app = context["app"] as? SerializedTypeDictionary
        XCTAssertEqual(os?["name"] as? String, "iOS")
        XCTAssertNotNil(os?["kernel_version"])
        XCTAssertEqual(device?["simulator"] as? Bool, true)
        XCTAssertNotNil(app?["app_id"])
    }
    #endif
    
}
