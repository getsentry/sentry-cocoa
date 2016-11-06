//
//  SentrySwiftCrashProbeTests.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 05/11/16.
//
//


import XCTest
import KSCrash
@testable import SentrySwift

class SentrySwiftCrashProbeTests: XCTestCase {
    
    let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
    let testHelper = SentrySwiftTestHelper()
    let crashReportConverter = CrashReportConverter()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCrashprobeCallAbort() { // Call abort()
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-3CCB10D2-F43D-45CB-8CB8-71A488F8E480")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "SIGABRT")
    }

    func testCrashprobeOverwriteLink() { // Overwrite link register, then crash
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-04DBADA2-A47E-4F18-B933-D21FF3981602")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }

    func testCrashprobeBadPointer() { // Dereference a bad pointer
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-5A3A2D67-08CE-4BC9-8F94-E108802723E6")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeJumpNXPage() { // Jump into an NX page
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-7F7C91BF-8A61-4BE7-8F1C-F73B9A2F7094")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeDWARF() { // DWARF Unwinding
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-9EDB3E3E-623C-401E-842A-229F175A1641")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeCorruptMalloc() { // Corrupt malloc()'s internal tracking information
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-61B40980-6C9D-4723-B6E2-B36A56843F02")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "SIGABRT")
    }
    
    func testCrashprobeThrowObjcException() { // Throw Objective-C exception
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-71AA0BD2-9397-4433-91FC-E9BA479F2518")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "NSGenericException")
    }
    
    func testCrashprobeDereferenceNullPointer() { // Dereference a NULL pointer
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-83DD68FA-9E95-4C93-ABD5-D216783A7961")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeMessageReleasedObject() { // Message a released object
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-85FEBAE4-57B9-4069-9C02-B25F475CD0FD")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeBuiltinTrap() { // Call __builtin_trap()
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-0414A4E8-FD05-407A-9319-4EA985BD8FE3")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_INSTRUCTION")
    }
    
    func testCrashprobeExecutePrivInstruction() { // Execute a privileged instruction
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-5956A91C-85E3-46FB-AB4E-8804C4100E1E")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeSwift() { // Swift
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-78391A99-7040-45F4-954B-A0D3111E617B")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_INSTRUCTION")
    }
    
    func testCrashprobePthreadListLock() { // Crash with _pthread_list_lock held
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-A720CEF9-E656-4AD2-A4AD-AFA0705F4174")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeAccessNonObject() { // Access a non-object as an object
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-BA2B2FC1-10EC-4D03-B46A-C5EFD50B1A04")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeWriteReadOnlyPage() { // Write to a read-only page
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-BAB8CCF2-2D03-49C4-B7DF-F64BBB1EC291")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeSmashBottomStack() { // Smash the bottom of the stack
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-BD5EDE57-9632-40AD-BD49-A483933995A8")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeSmashTopStack() { // Smash the top of the stack
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-C2E455F4-2B93-4B6C-AE71-2F820106CDFC")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeObjcMsgSend() { // Crash inside objc_msgSend()
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-C4E67714-AC95-4238-BAEF-9A584DBD9917")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeStackOverflow() { // Stack overflow
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-C8FBC583-4674-458B-A0FF-95DC6C4B82C4")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_ACCESS")
    }
    
    func testCrashprobeExecUndefInstruction() { // Execute an undefined instruction
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-D50B7169-45AA-41AD-9503-BF2F833D7BA1")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "EXC_BAD_INSTRUCTION")
    }
    
    
    func testCrashprobeThrowCPP() { // Throw C++ exception
        let crashJSON = testHelper.readIOSJSONCrashFile(name: "CrashProbeiOS-CrashReport-FF8CAD08-51C7-4443-B990-C3EFD8FAAC6D")!
        
        let event = crashReportConverter.mapReportToEvent(crashJSON)
        
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.exceptions?.first?.type, "cpp_exception")
    }
    
    
}
