//
//  SentrySwiftContextsTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 19/12/2016.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftContextsTests: XCTestCase {
    #if swift(>=3.0)
    func testContext() {
        let context = Contexts().serialized
        let os = context["os"] as? SerializedTypeDictionary
        let device = context["device"] as? SerializedTypeDictionary
        XCTAssertEqual(os?["name"] as? String, "iOS")
        XCTAssertNotNil(os?["kernel_version"])
        XCTAssertEqual(device?["simulator"] as? Bool, true)
    }
    #endif
}
