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
        let exception = NSException(name: NSExceptionName(name), reason: reason, userInfo: userInfo)
        
        let wrapper = SentryUseNSExceptionCallstackWrapper(exception: exception)
        
        // Make sure the name, reason and userInfo stay the same
        XCTAssertEqual(wrapper.name, NSExceptionName(name))
        XCTAssertEqual(wrapper.reason, reason)
        XCTAssertEqual(wrapper.userInfo as? [String: String], userInfo)
    }
    
    func testBuildThreads() {
        let addresses = [0x1234, 0x5678, 0x9ABC]
        // Use a fake exception so we can se the return addresses
        let exception = FakeException(returnAddresses: addresses.map { NSNumber(value: $0) })
        let wrapper = SentryUseNSExceptionCallstackWrapper(exception: exception)
        
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
        // Use a fake exception so we can se the return addresses
        let exception = FakeException(returnAddresses: [])
        let wrapper = SentryUseNSExceptionCallstackWrapper(exception: exception)
        
        let threads = wrapper.buildThreads()
        
        XCTAssertEqual(threads.count, 1)
        let thread = threads[0]
        XCTAssertNotNil(thread.stacktrace)
        XCTAssertEqual(thread.stacktrace?.frames.count, 0)
    }
    
    private class FakeException: NSObject, ExceptionProtocol {
        let addresses: [NSNumber]
        
        init(returnAddresses: [NSNumber]) {
            addresses = returnAddresses
            super.init()
        }
        
        func name() -> String {
            "TestException"
        }
        
        func reason() -> String {
            "Test Reason"
        }
        
        func userInfo() -> [AnyHashable: Any] {
            ["key": "value"]
        }
        
        func callStackReturnAddresses() -> [NSNumber] {
            addresses
        }
    }
}
#endif // os(macOS)
