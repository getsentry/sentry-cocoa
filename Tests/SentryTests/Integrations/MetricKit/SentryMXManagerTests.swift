import MetricKit
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

import MetricKit

@available(macOS 12.0, *)
final class SentryMXManagerTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    private func givenSut(disableCrashDiagnostics: Bool = true) -> SentryMXManager {
        let sut = SentryMXManager(inAppLogic: SentryInAppLogic(inAppIncludes: []), attachDiagnosticAsAttachment: false, disableCrashDiagnostics: disableCrashDiagnostics)
        
        return sut
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
}

#endif
