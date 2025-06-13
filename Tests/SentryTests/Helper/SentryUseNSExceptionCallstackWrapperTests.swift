//
//  SentryUseNSExceptionCallstackWrapperTests.swift
//  SentryTests
//
//  Created by Itay Brenner on 30/5/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

@testable import Sentry
import XCTest

#if os(macOS)

class SentryUseNSExceptionCallstackWrapperTests: XCTestCase {
    func testInitWithException() {
        let name = "TestException"
        let reason = "Test Reason"
        let userInfo = ["key": "value"]
        
        let wrapper = SentryUseNSExceptionCallstackWrapper(name: NSExceptionName(name), reason: reason, userInfo: userInfo, callStackReturnAddresses: [])
        
        // Make sure the name, reason and userInfo stay the same
        XCTAssertEqual(wrapper.name, NSExceptionName(name))
        XCTAssertEqual(wrapper.reason, reason)
        XCTAssertEqual(wrapper.userInfo as? [String: String], userInfo)
    }
    
    func testBuildThreads() {
        let addresses = [0x1234, 0x5678, 0x9ABC]
        let wrapper = SentryUseNSExceptionCallstackWrapper(name: NSExceptionName(rawValue: "Exception Name"), reason: "Exception Reason", userInfo: [:], callStackReturnAddresses: addresses.map { NSNumber(value: $0) })
        
        let threads = wrapper.buildThreads()
        
        // Verify thread properties
        XCTAssertEqual(threads.count, 1)
        let thread = threads[0]
        XCTAssertEqual(thread.threadId, 0)
        XCTAssertEqual(thread.name, "NSException Thread")
        XCTAssertEqual(thread.crashed, true)
        XCTAssertEqual(thread.current, true)
        XCTAssertEqual(thread.isMain, true)
        
        XCTAssertNotNil(thread.stacktrace)
        XCTAssertNotNil(thread.stacktrace?.frames)
        
        // Addresses are in reverse order
        XCTAssertNotNil(thread.stacktrace?.frames[0].instructionAddress, sentry_formatHexAddressUInt64(UInt64(addresses[2])))
        XCTAssertNotNil(thread.stacktrace?.frames[1].instructionAddress, sentry_formatHexAddressUInt64(UInt64(addresses[1])))
        XCTAssertNotNil(thread.stacktrace?.frames[2].instructionAddress, sentry_formatHexAddressUInt64(UInt64(addresses[0])))
    }
    
    func testBuildThreadsWithEmptyCallStack() {
        let wrapper = SentryUseNSExceptionCallstackWrapper(name: NSExceptionName(rawValue: "Exception Name"), reason: "Exception Reason", userInfo: [:], callStackReturnAddresses: [])
        
        let threads = wrapper.buildThreads()
        
        XCTAssertEqual(threads.count, 1)
        let thread = threads[0]
        XCTAssertNotNil(thread.stacktrace)
        XCTAssertEqual(thread.stacktrace?.frames.count, 0)
    }
}
#endif // os(macOS)
