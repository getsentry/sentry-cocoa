//
//  SentryCrashCTests.swift
//  Sentry
//
//  Created by Philip Niedertscheider on 13.12.24.
//  Copyright © 2024 Sentry. All rights reserved.
//

@testable import Sentry
import XCTest

class SentryCrashCTests: XCTestCase {

    func testOnCrash_notCrashedDuringCrashHandling_shouldWriteReportToDisk() {
        // -- Arrange --
        var appName = "SentryCrashCTests"
            .cString(using: .utf8)!
        let workDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-case-\(UUID().uuidString)")
        let installDir = workDir
            .appendingPathComponent(Array(repeating: "X", count: 100).joined())
        var installPath = installDir
            .path
            .cString(using: .utf8)!

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_install(&appName, &installPath)

        var monitorContext = SentryCrash_MonitorContext(
            eventID: nil,
            requiresAsyncSafety: false,
            handlingCrash: false,
            crashedDuringCrashHandling: false,
            registersAreValid: false,
            isStackOverflow: false,
            offendingMachineContext: nil,
            faultAddress: 0,
            crashType: SentryCrashMonitorTypeCPPException,
            exceptionName: nil,
            crashReason: nil,
            stackCursor: nil,
            mach: SentryCrash_MonitorContext.__Unnamed_struct_mach(),
            NSException: SentryCrash_MonitorContext.__Unnamed_struct_NSException(),
            CPPException: SentryCrash_MonitorContext.__Unnamed_struct_CPPException(),
            signal: SentryCrash_MonitorContext.__Unnamed_struct_signal(),
            userException: SentryCrash_MonitorContext.__Unnamed_struct_userException(),
            AppState: SentryCrash_MonitorContext.__Unnamed_struct_AppState(),
            System: SentryCrash_MonitorContext.__Unnamed_struct_System(),
            ZombieException: SentryCrash_MonitorContext.__Unnamed_struct_ZombieException()
        )
        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&monitorContext)

        // -- Assert --
        let expectedCrashStatePath = installDir
            .appendingPathComponent("Data")
            .appendingPathComponent("CrashState")
            .appendingPathExtension("json")
            .path
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedCrashStatePath))
    }

    func testOnCrash_notCrashedDuringCrashHandling_installFilePathTooLong_shouldNotWriteToDisk() {
        // -- Arrange --
        var appName = "SentryCrashCTests"
            .cString(using: .utf8)!
        let workDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-case-\(UUID().uuidString)")
        let installDir = workDir
            .appendingPathComponent(Array(repeating: "X", count: 500).joined())
        var installPath = installDir
            .path
            .cString(using: .utf8)!

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_install(&appName, &installPath)

        var monitorContext = SentryCrash_MonitorContext(
            eventID: nil,
            requiresAsyncSafety: false,
            handlingCrash: false,
            crashedDuringCrashHandling: false,
            registersAreValid: false,
            isStackOverflow: false,
            offendingMachineContext: nil,
            faultAddress: 0,
            crashType: SentryCrashMonitorTypeCPPException,
            exceptionName: nil,
            crashReason: nil,
            stackCursor: nil,
            mach: SentryCrash_MonitorContext.__Unnamed_struct_mach(),
            NSException: SentryCrash_MonitorContext.__Unnamed_struct_NSException(),
            CPPException: SentryCrash_MonitorContext.__Unnamed_struct_CPPException(),
            signal: SentryCrash_MonitorContext.__Unnamed_struct_signal(),
            userException: SentryCrash_MonitorContext.__Unnamed_struct_userException(),
            AppState: SentryCrash_MonitorContext.__Unnamed_struct_AppState(),
            System: SentryCrash_MonitorContext.__Unnamed_struct_System(),
            ZombieException: SentryCrash_MonitorContext.__Unnamed_struct_ZombieException()
        )
        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&monitorContext)

        // -- Assert --
        // Check the report was written to the truncated file path
        let expectedCrashStatePath = installDir
            .appendingPathComponent("Data")
            .appendingPathComponent("CrashState")
            .appendingPathExtension("json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedCrashStatePath.path))
    }

//    func testOnCrash_crashedDuringCrashHandling_shouldWriteReportToDisk() {
//        // -- Arrange --
//        var appName = "SentryCrashCTests"
//            .cString(using: .utf8)!
//        let workDir = URL(fileURLWithPath: NSTemporaryDirectory())
//            .appendingPathComponent("test-case-\(UUID().uuidString)")
//        let installDir = workDir
//            .appendingPathComponent(Array(repeating: "X", count: 100).joined())
//        var installPath = installDir
//            .path
//            .cString(using: .utf8)!
//
//        // Installing the sentrycrash will setup the exception handler
//        sentrycrash_install(&appName, &installPath)
//
//        // -- Act --
//        // Calling the handle exception will trigger the onCrash handler
//        var monitorContext = SentryCrash_MonitorContext(
//            eventID: nil,
//            requiresAsyncSafety: false,
//            handlingCrash: false,
//            crashedDuringCrashHandling: false,
//            registersAreValid: false,
//            isStackOverflow: false,
//            offendingMachineContext: nil,
//            faultAddress: 0,
//            crashType: SentryCrashMonitorTypeCPPException,
//            exceptionName: nil,
//            crashReason: nil,
//            stackCursor: nil,
//            mach: SentryCrash_MonitorContext.__Unnamed_struct_mach(),
//            NSException: SentryCrash_MonitorContext.__Unnamed_struct_NSException(),
//            CPPException: SentryCrash_MonitorContext.__Unnamed_struct_CPPException(),
//            signal: SentryCrash_MonitorContext.__Unnamed_struct_signal(),
//            userException: SentryCrash_MonitorContext.__Unnamed_struct_userException(),
//            AppState: SentryCrash_MonitorContext.__Unnamed_struct_AppState(),
//            System: SentryCrash_MonitorContext.__Unnamed_struct_System(),
//            ZombieException: SentryCrash_MonitorContext.__Unnamed_struct_ZombieException()
//        )
//        sentrycrashcm_handleException(&monitorContext)
//
//        // Calling the handler again with 'crashedDuringCrashHandling' will rewrite the crash report
//        struct SentryCrashMachineContext {
//            var thisThread: thread_t // Maps directly if imported from C
//            var allThreads: [thread_t] // Array to handle up to 100 threads
//            var threadCount: Int
//            var isCrashedContext: Bool
//            var isCurrentThread: Bool
//            var isStackOverflow: Bool
//            var isSignalContext: Bool
//        }
//        var machineContext = SentryCrashMachineContext(
//            thisThread: 0,
//            allThreads: Array(repeating: 0, count: 100),
//            threadCount: 0,
//            isCrashedContext: false,
//            isCurrentThread: false,
//            isStackOverflow: false,
//            isSignalContext: false
//        )
//        withUnsafeMutablePointer(to: &machineContext) { offendingMachineContextPtr in
//            SentryCrashDefaultMachineContextWrapper()
//                .fillContext(
//                    forCurrentThread: OpaquePointer(offendingMachineContextPtr)
//                )
//            monitorContext = SentryCrash_MonitorContext(
//                eventID: nil,
//                requiresAsyncSafety: false,
//                handlingCrash: false,
//                crashedDuringCrashHandling: true,
//                registersAreValid: false,
//                isStackOverflow: false,
//                offendingMachineContext: OpaquePointer(offendingMachineContextPtr),
//                faultAddress: 0,
//                crashType: SentryCrashMonitorTypeCPPException,
//                exceptionName: nil,
//                crashReason: nil,
//                stackCursor: nil,
//                mach: SentryCrash_MonitorContext.__Unnamed_struct_mach(),
//                NSException: SentryCrash_MonitorContext.__Unnamed_struct_NSException(),
//                CPPException: SentryCrash_MonitorContext.__Unnamed_struct_CPPException(),
//                signal: SentryCrash_MonitorContext.__Unnamed_struct_signal(),
//                userException: SentryCrash_MonitorContext.__Unnamed_struct_userException(),
//                AppState: SentryCrash_MonitorContext.__Unnamed_struct_AppState(),
//                System: SentryCrash_MonitorContext.__Unnamed_struct_System(),
//                ZombieException: SentryCrash_MonitorContext.__Unnamed_struct_ZombieException()
//            )
//            sentrycrashcm_handleException(&monitorContext)
//        }
//
//        // -- Assert --
//        let expectedCrashStatePath = installDir
//            .appendingPathComponent("Data")
//            .appendingPathComponent("CrashState")
//            .appendingPathExtension("json")
//            .path
//        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedCrashStatePath))
//    }
}
