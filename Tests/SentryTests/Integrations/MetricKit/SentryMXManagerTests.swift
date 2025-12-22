import MetricKit
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS)

import MetricKit

@available(macOS 12.0, *)
final class SentryMXManagerTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testReceiveNoPayloads() {
            let (sut, delegate) = givenSut()
            
            sut.didReceive([])
            
            XCTAssertEqual(0, delegate.crashInvocations.count)
            XCTAssertEqual(0, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(0, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(0, delegate.hangDiagnosticInvocations.count)
    }
    
    func testReceiveCrashPayload_DoesNothing() throws {
            let (sut, delegate) = givenSut()
            
            let payload = try givenPayloads()
            
            sut.didReceive([payload])
            
            XCTAssertEqual(0, delegate.crashInvocations.count)
            XCTAssertEqual(1, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(1, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(1, delegate.hangDiagnosticInvocations.count)
    }
    
    func testReceivePayloadsWithFaultyJSON_DoesNothing() throws {
            let (sut, delegate) = givenSut(disableCrashDiagnostics: false)
            
            let payload = try givenPayloads(withCallStackJSON: false)
            
            sut.didReceive([payload])
            
            XCTAssertEqual(0, delegate.crashInvocations.count)
            XCTAssertEqual(0, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(0, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(0, delegate.hangDiagnosticInvocations.count)
    }
    
    func testReceiveCrashPayloadEnabled_ForwardPayload() throws {
            let (sut, delegate) = givenSut(disableCrashDiagnostics: false)
            
            let payload = try givenPayloads()
            
            sut.didReceive([payload])
            
            XCTAssertEqual(1, delegate.crashInvocations.count)
            XCTAssertEqual(1, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(1, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(1, delegate.hangDiagnosticInvocations.count)
    }
    
    private func givenSut(disableCrashDiagnostics: Bool = true) -> (SentryMXManager, SentryMXManagerTestDelegate) {
        let sut = SentryMXManager(disableCrashDiagnostics: disableCrashDiagnostics)
        let delegate = SentryMXManagerTestDelegate()
        sut.delegate = delegate
        
        return (sut, delegate)
    }
    
    private func givenPayloads(withCallStackJSON: Bool = true) throws -> TestMXDiagnosticPayload {
        let payload = TestMXDiagnosticPayload()
        
        let callStackTree = TestMXCallStackTree()
        if withCallStackJSON {
            callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        }
        
        let crashDiagnostic = TestMXCrashDiagnostic()
        crashDiagnostic.overrides.callStackTree = callStackTree
        
        let cpuDiagnostic = TestMXCPUExceptionDiagnostic()
        cpuDiagnostic.overrides.callStackTree = callStackTree
        
        let diskWriteDiagnostic = TestMXDiskWriteExceptionDiagnostic()
        diskWriteDiagnostic.overrides.callStackTree = callStackTree
        
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        
        payload.overrides.crashDiagnostics = [crashDiagnostic]
        payload.overrides.cpuDiagnostic = [cpuDiagnostic]
        payload.overrides.diskWriteDiagnostic = [diskWriteDiagnostic]
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        
        return payload
    }
}

@available(macOS 12.0, *)
class TestMXDiagnosticPayload: MXDiagnosticPayload {
    struct Override {
        var crashDiagnostics: [MXCrashDiagnostic]?
        var cpuDiagnostic: [MXCPUExceptionDiagnostic]?
        var diskWriteDiagnostic: [MXDiskWriteExceptionDiagnostic]?
        var hangDiagnostic: [MXHangDiagnostic]?
        
        var timeStampBegin = SentryDependencyContainer.sharedInstance().dateProvider.date()
        var timeStampEnd = SentryDependencyContainer.sharedInstance().dateProvider.date()
    }
    
    var overrides = Override()
    
    override var crashDiagnostics: [MXCrashDiagnostic]? {
        return overrides.crashDiagnostics
    }
    
    override var cpuExceptionDiagnostics: [MXCPUExceptionDiagnostic]? {
        return overrides.cpuDiagnostic
    }
    
    override var diskWriteExceptionDiagnostics: [MXDiskWriteExceptionDiagnostic]? {
        return overrides.diskWriteDiagnostic
    }
    
    override var hangDiagnostics: [MXHangDiagnostic]? {
        return overrides.hangDiagnostic
    }
    
    override var timeStampBegin: Date {
        return overrides.timeStampBegin
    }
    
    override var timeStampEnd: Date {
        return overrides.timeStampEnd
    }
}

@available(macOS 12.0, *)
class SentryMXManagerTestDelegate: SentryMXManagerDelegate {

    var crashInvocations = Invocations<(diagnostic: MXCrashDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date)>()
    func didReceiveCrashDiagnostic(_ diagnostic: MXCrashDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date) {
        crashInvocations.record((diagnostic, callStackTree, timeStampBegin))
    }
    
    var diskWriteExceptionInvocations = Invocations<(diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date)>()
    func didReceiveDiskWriteExceptionDiagnostic(_ diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date) {
        diskWriteExceptionInvocations.record((diagnostic, callStackTree, timeStampBegin))
    }
    
    var cpuExceptionInvocations = Invocations<(diagnostic: MXCPUExceptionDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date)>()
    func didReceiveCpuExceptionDiagnostic(_ diagnostic: MXCPUExceptionDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date) {
        cpuExceptionInvocations.record((diagnostic, callStackTree, timeStampBegin))
    }
    
    var hangDiagnosticInvocations = Invocations<(diagnostic: MXHangDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date)>()
    func didReceiveHangDiagnostic(_ diagnostic: MXHangDiagnostic, callStackTree: Sentry.SentryMXCallStackTree, timeStampBegin: Date) {
        hangDiagnosticInvocations.record((diagnostic, callStackTree, timeStampBegin))
    }
}

#endif
