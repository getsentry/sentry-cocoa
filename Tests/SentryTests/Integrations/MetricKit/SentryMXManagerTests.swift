@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

import MetricKit

final class SentryMXManagerTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    private func givenSut(disableCrashDiagnostics: Bool = true) -> SentryMXManager {
        let sut = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: SentryMXManager.DiagnosticMetric.all
                .subtracting(disableCrashDiagnostics ? [.crashDiagnostics] : [])
        )

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
