import MetricKit
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS)

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no compiler directives for iOS versions we use canImport.
 */
#if canImport(MetricKit)
import MetricKit
#endif

final class SentryMXManagerTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testReceiveNoPayloads() {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let (sut, delegate) = givenSut()
            
            sut.didReceive([])
            
            XCTAssertEqual(0, delegate.crashInvocations.count)
            XCTAssertEqual(0, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(0, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(0, delegate.hangDiagnosticInvocations.count)
        }
    }
    
    func testReceiveCrashPayload_DoesNothing() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let (sut, delegate) = givenSut()
            
            let payload = try givenPayloads()
            
            sut.didReceive([payload])
            
            XCTAssertEqual(0, delegate.crashInvocations.count)
            XCTAssertEqual(1, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(1, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(1, delegate.hangDiagnosticInvocations.count)
        }
    }
    
    func testReceivePayloadsWithFaultyJSON_DoesNothing() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let (sut, delegate) = givenSut(disableCrashDiagnostics: false)
            
            let payload = try givenPayloads(withCallStackJSON: false)
            
            sut.didReceive([payload])
            
            XCTAssertEqual(0, delegate.crashInvocations.count)
            XCTAssertEqual(0, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(0, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(0, delegate.hangDiagnosticInvocations.count)
        }
    }
    
    func testReceiveCrashPayloadEnabled_ForwardPayload() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let (sut, delegate) = givenSut(disableCrashDiagnostics: false)
            
            let payload = try givenPayloads()
            
            sut.didReceive([payload])
            
            XCTAssertEqual(1, delegate.crashInvocations.count)
            XCTAssertEqual(1, delegate.diskWriteExceptionInvocations.count)
            XCTAssertEqual(1, delegate.cpuExceptionInvocations.count)
            XCTAssertEqual(1, delegate.hangDiagnosticInvocations.count)
        }
    }
    
    @available(iOS 15, macOS 12, macCatalyst 15, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    private func givenSut(disableCrashDiagnostics: Bool = true) -> (SentryMXManager, SentryMXManagerTestDelegate) {
        let sut = SentryMXManager(disableCrashDiagnostics: disableCrashDiagnostics)
        let delegate = SentryMXManagerTestDelegate()
        sut.delegate = delegate
        
        return (sut, delegate)
    }
    
    @available(iOS 15, macOS 12, macCatalyst 15, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
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

@available(iOS 15, macOS 12, macCatalyst 15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class SentryMXManagerTestDelegate: SentryMXManagerDelegate {

    var crashInvocations = Invocations<(diagnostic: MXCrashDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)>()
    func didReceiveCrashDiagnostic(_ diagnostic: MXCrashDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date) {
        crashInvocations.record((diagnostic, callStackTree, timeStampBegin, timeStampEnd))
    }
    
    var diskWriteExceptionInvocations = Invocations<(diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)>()
    func didReceiveDiskWriteExceptionDiagnostic(_ diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date) {
        diskWriteExceptionInvocations.record((diagnostic, callStackTree, timeStampBegin, timeStampEnd))
    }
    
    var cpuExceptionInvocations = Invocations<(diagnostic: MXCPUExceptionDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)>()
    func didReceiveCpuExceptionDiagnostic(_ diagnostic: MXCPUExceptionDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date) {
        cpuExceptionInvocations.record((diagnostic, callStackTree, timeStampBegin, timeStampEnd))
    }
    
    var hangDiagnosticInvocations = Invocations<(diagnostic: MXHangDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)>()
    func didReceiveHangDiagnostic(_ diagnostic: MXHangDiagnostic, callStackTree: SentryPrivate.SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date) {
        hangDiagnosticInvocations.record((diagnostic, callStackTree, timeStampBegin, timeStampEnd))
    }
}

#endif
