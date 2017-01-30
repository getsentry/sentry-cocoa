//
//  SentrySwiftUserFeedback.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 17/11/16.
//
//

import XCTest
@testable import Sentry

class SentrySwiftUserFeedback: XCTestCase {
    
    func testUserFeedbackObject() {
        let event = Event.build("Another example 4") {
            $0.level = .Fatal
            $0.tags = ["status": "test"]
            $0.extra = [
                "name": "Josh Holtz",
                "favorite_power_ranger": "green/white"
            ]
        }
        
        let userFeedback = UserFeedback()
        userFeedback.name = "a"
        userFeedback.email = "b"
        userFeedback.comments = "c"
        userFeedback.event = event
        
        #if swift(>=3.0)
            XCTAssertEqual(userFeedback.serialized, "email=b&name=a&comments=c".data(using: String.Encoding.utf8))
        #else
            XCTAssertEqual(userFeedback.serialized, "email=b&name=a&comments=c".dataUsingEncoding(NSUTF8StringEncoding))
        #endif
        
        let userFeedbackEncoding = UserFeedback()
        userFeedbackEncoding.name = "\"äßa"
        userFeedbackEncoding.email = "??><MNBVCXZ~}{POIUYTREWQ|'"
        userFeedbackEncoding.comments = "_)(*&^%$#@!🚀"
        userFeedbackEncoding.event = event
        
        #if swift(>=3.0)
            XCTAssertEqual(userFeedbackEncoding.serialized, "email=%3F%3F><MNBVCXZ~}{POIUYTREWQ|%27&name=\"%C3%A4%C3%9Fa&comments=_%29%28%2A%26^%25%24%23%40%21%F0%9F%9A%80".data(using: String.Encoding.utf8))
        #else
            XCTAssertEqual(userFeedbackEncoding.serialized, "email=%3F%3F><MNBVCXZ~}{POIUYTREWQ|%27&name=\"%C3%A4%C3%9Fa&comments=_%29%28%2A%26^%25%24%23%40%21%F0%9F%9A%80".dataUsingEncoding(NSUTF8StringEncoding))
        #endif
        
        XCTAssertEqual(userFeedbackEncoding.queryItems, [
            URLQueryItem(name: "email", value: "%3F%3F><MNBVCXZ~}{POIUYTREWQ|%27"),
            URLQueryItem(name: "eventId", value: event.eventID)
        ])
        
        #if swift(>=3.0)
        let userFeedbackEncodingFail = UserFeedback()
        userFeedbackEncodingFail.name = String(
            bytes: [0xD8, 0x00] as [UInt8],
            encoding: String.Encoding.utf16BigEndian)!
        userFeedbackEncodingFail.email = "b"
        userFeedbackEncodingFail.comments = "c"
        userFeedbackEncodingFail.event = event
        
        XCTAssertNil(userFeedbackEncodingFail.serialized)
        #endif
    }
    
    #if swift(>=3.0)
    func testUserFeedbackViewModel() {
        let viewModel = UserFeedbackViewModel()
        
        let nameField = UITextField()
        nameField.text = ""
        
        let emailField = UITextField()
        emailField.text = "a"
        
        let commentsField = UITextField()
        commentsField.text = ""
        
        XCTAssertFalse(viewModel.submitButtonEnabled)
        
        XCTAssertEqual(viewModel.validatedUserFeedback(nameField, emailTextField: emailField, commentsTextField: commentsField), nameField)
        
        nameField.text = "a"
        
        viewModel.sendUserFeedback { (success) in
            XCTAssertFalse(success)
        }

        XCTAssertEqual(viewModel.validatedUserFeedback(nameField, emailTextField: emailField, commentsTextField: commentsField), emailField)
        
        emailField.text = "daniel@getsentry.com"
        
        XCTAssertEqual(viewModel.validatedUserFeedback(nameField, emailTextField: emailField, commentsTextField: commentsField), commentsField)
        
        commentsField.text = "Comment"
        
        XCTAssertEqual(viewModel.validatedUserFeedback(nameField, emailTextField: emailField, commentsTextField: commentsField), nil)
        
        XCTAssertTrue(viewModel.submitButtonEnabled)
        
        let asyncExpectation = expectation(description: "sendUserFeedback")
        
        viewModel.sendUserFeedback { (success) in
            XCTAssertTrue(false)
        }
        
        let client = SentrySwiftTestHelper.sentryMockClient
        client.captureEvent(SentrySwiftTestHelper.demoFatalEvent, useClientProperties: true) { (success) in
            XCTAssertTrue(success)
            viewModel.sendUserFeedback { (success) in
                XCTAssertTrue(success)
                asyncExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
        }
    }
    #endif
    
}
