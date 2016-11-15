//
//  SentrySwiftRequestTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 15/11/16.
//
//

import XCTest
@testable import SentrySwift

class SentrySwiftRequestTests: XCTestCase {
    
    let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
    let frame = Frame(file: "a", function: "b", line: 1)


    func testExample() {
        let event = Event.build("Another example 4") {
            $0.level = .Fatal
            $0.tags = ["status": "test"]
            $0.extra = [
                "name": "Josh Holtz",
                "favorite_power_ranger": "green/white"
            ]
        }
        client.sendEvent(event) { [weak self] success in
            
        }
    }

}
