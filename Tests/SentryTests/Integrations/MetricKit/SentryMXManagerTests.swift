#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
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
    
    func testReceiveReports_whenSwiftAPIUnavailable_shouldSubscribeToMXManager() throws {
        #if os(iOS) && compiler(>=6.4) && canImport(StateReporting)
        if #available(iOS 27.0, *) { throw XCTSkip("Uses MetricKit's Swift API instead") }
        #endif
        // -- Arrange --
        let manager = RecordingMetricManager()
        let sut = SentryMXManager(metricManager: manager, inAppLogic: SentryInAppLogic(inAppIncludes: []), attachDiagnosticAsAttachment: false, processStartDate: .distantPast)

        // -- Act --
        sut.receiveReports()
        sut.pauseReports()

        // -- Assert --
        XCTAssertEqual(manager.subscriptions, 1)
        XCTAssertEqual(manager.removals, 1)
    }

    #if os(iOS) && compiler(>=6.4) && canImport(StateReporting)
    func testReceiveReports_whenSwiftAPIAvailable_shouldNotSubscribeToMXManager() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires MetricKit's Swift API") }
        // -- Arrange --
        let manager = RecordingMetricManager()
        let sut = SentryMXManager(metricManager: manager, inAppLogic: SentryInAppLogic(inAppIncludes: []), attachDiagnosticAsAttachment: false, processStartDate: .distantPast)

        // -- Act --
        sut.receiveReports()
        sut.pauseReports()

        // -- Assert --
        XCTAssertEqual(manager.subscriptions, 0)
        XCTAssertEqual(manager.removals, 0)
    }
    #endif

    private func givenSut(disableCrashDiagnostics: Bool = true) -> SentryMXManager {
        let sut = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: SentryMXManager.Diagnostic.all
                .subtracting(disableCrashDiagnostics ? [.crash] : []),
            // Every payload counts as recorded by this process.
            processStartDate: .distantPast
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

private final class RecordingMetricManager: SentryMetricManager {
    var subscriptions = 0
    var removals = 0

    func add(_ subscriber: MXMetricManagerSubscriber) {
        subscriptions += 1
    }

    func remove(_ subscriber: MXMetricManagerSubscriber) {
        removals += 1
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
