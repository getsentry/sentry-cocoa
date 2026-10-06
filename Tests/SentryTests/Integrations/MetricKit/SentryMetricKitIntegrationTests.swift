@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {

    var callStackTreePerThread: SentryMXCallStackTree!
    var callStackTreeNotPerThread: SentryMXCallStackTree!
    var timeStampBegin: Date!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let contentsPerThread = try contentsOfResource("MetricKitCallstacks/per-thread")
        callStackTreePerThread = try SentryMXCallStackTree.from(data: contentsPerThread)

        let contentsNotPerThread = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        callStackTreeNotPerThread = try SentryMXCallStackTree.from(data: contentsNotPerThread)

        timeStampBegin = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(21.23)
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

#if !SDK_V10
    func testOptionEnabled_MetricKitManagerInitialized() {
          let options = Options()
          options.enableMetricKit = true
          let sut = SentryMetricKitIntegration(with: options, dependencies: ())
          XCTAssertNotNil(sut)
    }

    func testOptionDisabled_MetricKitManagerNotInitialized() {
          let options = Options()
          options.enableMetricKit = false
          let sut = SentryMetricKitIntegration(with: options, dependencies: ())
          XCTAssertNil(sut)
    }

    func testInit_whenDiagnosticReportsNotConfigured_shouldUseDefaultDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.enableMetricKit = true

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        // -- Assert --
        XCTAssertEqual(sut.mxManager.enabledDiagnostics, [.cpuException, .diskWriteException, .hang])
    }

    func testInit_whenMetricKitDisabledAndDiagnosticReportsConfigured_shouldUseConfiguredDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.enableMetricKit = false
        options.experimental.metricKit.enabledDiagnosticReports = [.hang]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        // -- Assert --
        // Before v10 a configured set of reports opts in on its own.
        XCTAssertEqual(sut.mxManager.enabledDiagnostics, [.hang])
    }
#endif // !SDK_V10

    func testInit_whenDiagnosticReportsConfigured_shouldUseConfiguredDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metricKit.enabledDiagnosticReports = [.hang, .crash]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        // -- Assert --
        XCTAssertEqual(sut.mxManager.enabledDiagnostics, [.hang, .crash])
    }

    func testInit_whenDiagnosticReportsEmpty_shouldDependOnSDKVersion() throws {
        // -- Arrange --
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.experimental.metricKit.enabledDiagnosticReports = []

        // -- Act --
        let sut = SentryMetricKitIntegration(with: options, dependencies: ())

        // -- Assert --
#if SDK_V10
        XCTAssertNil(sut)
#else
        // Before v10 an empty set leaves the decision to enableMetricKit.
        XCTAssertEqual(try XCTUnwrap(sut).mxManager.enabledDiagnostics, [.cpuException, .diskWriteException, .hang])
#endif
    }

    func testInit_whenDefaultOptions_shouldDependOnSDKVersion() throws {
        // -- Arrange --
        let options = Options()

        // -- Act --
        let sut = SentryMetricKitIntegration(with: options, dependencies: ())

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(try XCTUnwrap(sut).mxManager.enabledDiagnostics, [.cpuException, .diskWriteException, .hang])
#else
        XCTAssertNil(sut)
#endif
    }

    func testDidReceive_whenCrashDiagnosticHasExceptionInfo_shouldFormatExceptionValue() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.experimental.metricKit.enabledDiagnosticReports = [.crash]
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
        let crashDiagnostic = TestMXCrashDiagnostic()
        crashDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        crashDiagnostic.overrides.exceptionType = 1
        crashDiagnostic.overrides.exceptionCode = 0
        crashDiagnostic.overrides.signal = 11
        let payload = TestMXDiagnosticPayload()
        payload.overrides.crashDiagnostics = [crashDiagnostic]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            let exception = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(exception.value, "MachException Type:1 Code:0 Signal:11")
            XCTAssertEqual(exception.type, "MXCrashDiagnostic")
            XCTAssertEqual(exception.mechanism?.type, "MXCrashDiagnostic")
            XCTAssertEqual(exception.mechanism?.handled, false)
        }
    }

    func testMXCrashPayloadReceived() throws {
            givenSDKWithHubWithScope()

        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: [.crash]
        )

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let crashDiagnostic = TestMXCrashDiagnostic()
        crashDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.crashDiagnostics = [crashDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.didReceive([payload])

        try assertPerThread(exceptionType: "MXCrashDiagnostic", exceptionValue: "MachException Type:nil Code:nil Signal:nil", exceptionMechanism: "MXCrashDiagnostic", handled: false)
    }

    func testDidReceive_whenHangDiagnosticsDisabled_shouldNotCaptureEvent() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: [.crash]
        )
        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        assertNothingCaptured()
    }

    func testAttachDiagnosticAsAttachment() throws {
            givenSDKWithHubWithScope()

        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.enableMetricKitRawPayload = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            try assertEventWithScopeCaptured { _, scope, _ in
                let diagnosticAttachment = scope?.attachments.first { $0.filename == "MXDiagnosticPayload.json" }

                let attachmentJSON = try JSONSerialization.jsonObject(with: XCTUnwrap(diagnosticAttachment?.data)) as? NSDictionary
                let diagnosticJSON = try JSONSerialization.jsonObject(with: hangDiagnostic.jsonRepresentation()) as? NSDictionary
                XCTAssertEqual(attachmentJSON, diagnosticJSON)
            }
    }

    func testDidReceive_whenRawDiagnosticIsPrettyPrinted_shouldAttachCompactJSON() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: true,
            enabledDiagnostics: [.hang]
        )
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        diagnostic.overrides.jsonRepresentation = Data("{\n  \"hangDuration\": \"6.6 sec\"\n}".utf8)
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { _, scope, _ in
            let attachment = try XCTUnwrap(scope?.attachments.first { $0.filename == "MXDiagnosticPayload.json" })
            XCTAssertEqual(attachment.data, Data(#"{"hangDuration":"6.6 sec"}"#.utf8))
        }
    }

    func testDidReceive_whenHangDecodingFailsAndRawPayloadEnabled_shouldCaptureRawDiagnostic() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.enableMetricKitRawPayload = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = Data(#"{"callStacks":"unexpected"}"#.utf8)
        let rawDiagnostic = Data(#"{"hangDuration":"6.6 sec","callStackTree":{"callStacks":"unexpected"}}"#.utf8)
        diagnostic.overrides.jsonRepresentation = rawDiagnostic
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            let event = try XCTUnwrap(event)
            XCTAssertEqual(event.timestamp, timeStampBegin)
            XCTAssertEqual(event.level, .error)
            let exception = try XCTUnwrap(event.exceptions?.first)
            XCTAssertEqual(exception.type, "MXHangDiagnostic")
            XCTAssertEqual(exception.value, "MXHangDiagnostic hangDuration:6.6 sec")
            XCTAssertEqual(exception.mechanism?.type, "mx_hang_diagnostic")
            XCTAssertEqual(exception.mechanism?.handled, true)
            XCTAssertEqual(exception.mechanism?.synthetic, true)
            XCTAssertNil(exception.stacktrace)
            XCTAssertNil(exception.threadId)
            XCTAssertNil(event.threads)
            XCTAssertNil(event.debugMeta)
            let attachments = try XCTUnwrap(scope?.attachments.filter { $0.filename == "MXDiagnosticPayload.json" })
            XCTAssertEqual(attachments.count, 1)
            let attachmentJSON = try JSONSerialization.jsonObject(with: XCTUnwrap(attachments.first?.data)) as? NSDictionary
            let diagnosticJSON = try JSONSerialization.jsonObject(with: rawDiagnostic) as? NSDictionary
            XCTAssertEqual(attachmentJSON, diagnosticJSON)
        }
        XCTAssertEqual(diagnostic.jsonRepresentationInvocations.count, 1)
    }

    func testDidReceive_whenHangDecodingFailsAndRawPayloadDisabled_shouldDropDiagnostic() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.enableMetricKitRawPayload = false
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = Data(#"{"callStacks":"unexpected"}"#.utf8)
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        assertNothingCaptured()
        XCTAssertEqual(diagnostic.jsonRepresentationInvocations.count, 0)
    }

    func testDidReceive_whenMalformedHangPrecedesValidHang_shouldCaptureBothWithSeparateAttachments() throws {
        // -- Arrange --
        let scope = Scope()
        scope.addAttachment(TestData.dataAttachment)
        givenSdkWithHub(scope: scope)
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.enableMetricKitRawPayload = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let malformedDiagnostic = TestMXHangDiagnostic()
        malformedDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = Data(#"{"callStacks":"unexpected"}"#.utf8)
        let malformedJSON = Data(#"{"hangDuration":"6.6 sec","callStackTree":{"callStacks":"unexpected"}}"#.utf8)
        malformedDiagnostic.overrides.jsonRepresentation = malformedJSON

        let validDiagnostic = TestMXHangDiagnostic()
        let validCallStackJSON = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        validDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = validCallStackJSON
        let validJSON = try JSONSerialization.data(withJSONObject: [
            "hangDuration": "6.6 sec",
            "callStackTree": try JSONSerialization.jsonObject(with: validCallStackJSON)
        ])
        validDiagnostic.overrides.jsonRepresentation = validJSON

        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [malformedDiagnostic, validDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let captures = client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(captures.count, 2)
        let malformedCapture = try XCTUnwrap(captures.first)
        let validCapture = try XCTUnwrap(captures.element(at: 1))
        XCTAssertNil(malformedCapture.event.threads)
        XCTAssertNil(malformedCapture.event.exceptions?.first?.stacktrace)
        let validFrames = try XCTUnwrap(validCapture.event.exceptions?.first?.stacktrace?.frames)
        XCTAssertFalse(validFrames.isEmpty)

        for (capture, expectedJSON) in [(malformedCapture, malformedJSON), (validCapture, validJSON)] {
            XCTAssertEqual(capture.event.timestamp, timeStampBegin)
            let attachments = capture.scope.attachments.filter { $0.filename == "MXDiagnosticPayload.json" }
            XCTAssertEqual(attachments.count, 1)
            let attachmentJSON = try JSONSerialization.jsonObject(with: XCTUnwrap(attachments.first?.data)) as? NSDictionary
            let diagnosticJSON = try JSONSerialization.jsonObject(with: expectedJSON) as? NSDictionary
            XCTAssertEqual(attachmentJSON, diagnosticJSON)
        }
        XCTAssertFalse(scope.attachments.contains { $0.filename == "MXDiagnosticPayload.json" })
        XCTAssertEqual(malformedDiagnostic.jsonRepresentationInvocations.count, 1)
        XCTAssertEqual(validDiagnostic.jsonRepresentationInvocations.count, 1)
    }

    func testDontAttachDiagnosticAsAttachment() throws {
            givenSDKWithHubWithScope()

        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            try assertEventWithScopeCaptured { _, scope, _ in
                let diagnosticAttachment = scope?.attachments.first { $0.filename == "MXDiagnosticPayload.json" }

                XCTAssertNil(diagnosticAttachment)
            }
    }

    func testSetInAppIncludes_AppliesInAppToStackTrace() throws {
            givenSDKWithHubWithScope()

        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.add(inAppInclude: "iOS-Swift")
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            try assertEventWithScopeCaptured { event, _, _ in
                let stacktrace = try XCTUnwrap( event?.threads?.first?.stacktrace)

                let inAppFramesCount = stacktrace.frames.filter { $0.inApp as? Bool ?? false }.count

                XCTAssertEqual(2, inAppFramesCount)
            }
    }

    func testCPUExceptionDiagnostic_NotPerThread() throws {
            givenSDKWithHubWithScope()

            let options = Options()
            #if !SDK_V10
            options.enableMetricKit = true
            #endif // !SDK_V10
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        let cpuException = TestMXCPUExceptionDiagnostic()
        cpuException.overrides.callStackTree = callStackTree
        payload.overrides.cpuDiagnostic = [cpuException]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            try assertNotPerThread(exceptionType: "MXCPUException", exceptionValue: "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms", exceptionMechanism: "mx_cpu_exception")
    }

    func testCPUExceptionDiagnostic_OnlyOneFrame() throws {
            givenSDKWithHubWithScope()

            let options = Options()
            #if !SDK_V10
            options.enableMetricKit = true
            #endif // !SDK_V10
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let cpuException = TestMXCPUExceptionDiagnostic()
        cpuException.overrides.callStackTree = callStackTree
        payload.overrides.cpuDiagnostic = [cpuException]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
                XCTFail("Hub Client is not a `TestClient`")
                return
            }

            let invocations = client.captureEventWithScopeInvocations.invocations
            XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)

            try assertEvent(event: try XCTUnwrap(invocations.first).event)

            func assertEvent(event: Event) throws {
                let sentryFrames = try XCTUnwrap(event.threads?.first?.stacktrace?.frames, "Event has no frames.")

                XCTAssertEqual(1, sentryFrames.count)
                let frame = sentryFrames.first
                XCTAssertEqual("0x000000021f1a0001", frame?.imageAddress)
                XCTAssertEqual("libsystem_pthread.dylib", frame?.package)
                XCTAssertFalse(frame?.inApp?.boolValue ?? true)
            }
    }

    func testDiskWriteExceptionDiagnostic() throws {
            givenSDKWithHubWithScope()

            let options = Options()
            #if !SDK_V10
            options.enableMetricKit = true
            #endif // !SDK_V10
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let diskWriteException = TestMXDiskWriteExceptionDiagnostic()
        diskWriteException.overrides.callStackTree = callStackTree
        payload.overrides.diskWriteDiagnostic = [diskWriteException]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            try assertNotPerThread(exceptionType: "MXDiskWriteException", exceptionValue: "MXDiskWriteException totalWritesCaused:5.5 Mib", exceptionMechanism: "mx_disk_write_exception")
    }

    func testHangDiagnostic() throws {
            givenSDKWithHubWithScope()

            let options = Options()
            #if !SDK_V10
            options.enableMetricKit = true
            #endif // !SDK_V10
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.didReceive([payload])

            try assertNotPerThread(exceptionType: "MXHangDiagnostic", exceptionValue: "MXHangDiagnostic hangDuration:6.6 sec", exceptionMechanism: "mx_hang_diagnostic")
    }

    func testHangDiagnostic_shouldSetLevelBasedOnDuration() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")

        let majorHang = TestMXHangDiagnostic()
        majorHang.overrides.callStackTree = callStackTree
        majorHang.overrides.hangDuration = Measurement(value: 251, unit: .milliseconds)

        let severeThresholdHang = TestMXHangDiagnostic()
        severeThresholdHang.overrides.callStackTree = callStackTree
        severeThresholdHang.overrides.hangDuration = Measurement(value: 500, unit: .milliseconds)

        let severeHang = TestMXHangDiagnostic()
        severeHang.overrides.callStackTree = callStackTree
        severeHang.overrides.hangDuration = Measurement(value: 501, unit: .milliseconds)

        let criticalHang = TestMXHangDiagnostic()
        criticalHang.overrides.callStackTree = callStackTree
        criticalHang.overrides.hangDuration = Measurement(value: 1_001, unit: .milliseconds)

        payload.overrides.hangDiagnostic = [majorHang, severeThresholdHang, severeHang, criticalHang]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let invocations = client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(4, invocations.count)
        XCTAssertEqual([.warning, .warning, .error, .error], invocations.map(\.event.level))
    }

    func testDidReceive_whenDiagnosticFromPreviousAppVersion_shouldSetReleaseAndDistFromDiagnostic() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.releaseName, "io.sentry.app@1.2.3+45")
            XCTAssertEqual(event?.dist, "45")
        }
    }

    func testDidReceive_whenDiagnosticFromPreviousBuild_shouldSetReleaseAndDistFromDiagnostic() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "19")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.releaseName, "io.sentry.app@2.0.0+19")
            XCTAssertEqual(event?.dist, "19")
        }
    }

    func testDidReceive_whenDiagnosticFromCurrentAppVersion_shouldNotSetReleaseAndDist() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
        }
    }

    func testDidReceive_whenCustomReleaseNameAndDiagnosticFromPreviousAppVersion_shouldNotSetReleaseAndDist() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "my-custom-release")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
        }
    }

    func testDidReceive_whenDiagnosticHasMetadata_shouldReplaceAppAndOSContextOnScope() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45", osVersion: "iPhone OS 18.6.2 (22G100)")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            // The contexts are set on the scope, because the scope merge can't remove keys.
            XCTAssertNil(event?.context)
            XCTAssertEqual(scope?.getContextForKey("app") as NSDictionary?, [
                "app_identifier": "io.sentry.app",
                "app_version": "1.2.3",
                "app_build": "45"
            ])
            XCTAssertEqual(scope?.getContextForKey("os") as NSDictionary?, [
                "name": "iOS",
                "version": "18.6.2",
                "build": "22G100"
            ])
        }
    }

    func testDidReceive_whenDiagnosticHasOnlyAppVersion_shouldSetAppContextWithoutBuild() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { _, scope, _ in
            XCTAssertEqual(scope?.getContextForKey("app") as NSDictionary?, [
                "app_identifier": "io.sentry.app",
                "app_version": "1.2.3"
            ])
        }
    }

    func testDidReceive_whenScopeHasNoAppContext_shouldSetAppVersionAndBuildOnScope() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        SentrySDKInternal.currentHub().scope.removeContext(key: "app")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { _, scope, _ in
            XCTAssertEqual(scope?.getContextForKey("app") as NSDictionary?, ["app_version": "1.2.3", "app_build": "45"])
        }
    }

    func testDidReceive_whenOSVersionHasNoBuild_shouldSetOSContextWithoutBuild() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", osVersion: "macOS 14.1")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertNil(event?.context?["os"])
            XCTAssertEqual(scope?.getContextForKey("os") as NSDictionary?, ["name": "iOS", "version": "14.1"])
        }
    }

    func testDidReceive_whenScopeHasNoOSContext_shouldSetOSVersionAndBuildOnScope() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        SentrySDKInternal.currentHub().scope.removeContext(key: "os")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", osVersion: "iPhone OS 18.6.2 (22G100)")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { _, scope, _ in
            XCTAssertEqual(scope?.getContextForKey("os") as NSDictionary?, ["version": "18.6.2", "build": "22G100"])
        }
    }

    func testDidReceive_whenOSVersionIsUnparseable_shouldKeepOSContextOfScope() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", osVersion: "unknown")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertNil(event?.context?["os"])
            XCTAssertEqual(scope?.getContextForKey("os") as NSDictionary?, Self.runningOSContext as NSDictionary)
        }
    }

    func testDidReceive_shouldNotModifyAppAndOSContextOfHubScope() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45", osVersion: "iPhone OS 18.6.2 (22G100)")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        let hubScope = SentrySDKInternal.currentHub().scope
        XCTAssertEqual(hubScope.getContextForKey("app") as NSDictionary?, Self.runningAppContext as NSDictionary)
        XCTAssertEqual(hubScope.getContextForKey("os") as NSDictionary?, Self.runningOSContext as NSDictionary)
    }

    func testDidReceive_whenDiagnosticHasNoMetadata_shouldNotSetReleaseDistOrContext() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
            XCTAssertNil(event?.context)
            XCTAssertEqual(scope?.getContextForKey("app") as NSDictionary?, Self.runningAppContext as NSDictionary)
            XCTAssertEqual(scope?.getContextForKey("os") as NSDictionary?, Self.runningOSContext as NSDictionary)
        }
    }

    private func givenSut(releaseName: String?) -> SentryMXManager {
        SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: [.hang],
            releaseName: releaseName,
            bundleInfo: [
                "CFBundleIdentifier": "io.sentry.app",
                "CFBundleShortVersionString": "2.0.0",
                "CFBundleVersion": "20"
            ]
        )
    }

    private func givenHangPayload(
        appVersion: String,
        appBuild: String,
        osVersion: String = "iPhone OS 18.6.2 (22G100)"
    ) throws -> TestMXDiagnosticPayload {
        let metaData = TestMXMetaData()
        metaData.overrides.applicationBuildVersion = appBuild
        metaData.overrides.osVersion = osVersion

        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        diagnostic.overrides.metaData = metaData
        diagnostic.overrides.applicationVersion = appVersion

        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]
        return payload
    }

    private static let runningAppContext: [String: Any] = [
        "app_identifier": "io.sentry.app",
        "app_name": "SentryApp",
        "app_version": "2.0.0",
        "app_build": "20",
        "build_type": "app store",
        "app_start_time": "2026-10-05T10:00:00.000Z",
        "device_app_hash": "abc123"
    ]

    private static let runningOSContext: [String: Any] = [
        "name": "iOS",
        "version": "26.0",
        "build": "23A340",
        "kernel_version": "Darwin Kernel Version 25.0.0",
        "rooted": false
    ]

    private func givenSDKWithHubWithScope(appContext: [String: Any]? = nil, osContext: [String: Any]? = nil) {
        let scope = Scope()
        scope.addBreadcrumb(TestData.crumb)
        scope.addAttachment(TestData.dataAttachment)

        givenSdkWithHub(scope: scope)

        // Creating the hub enriches the scope with the running app and OS, so presets must come after.
        if let appContext {
            SentrySDKInternal.currentHub().scope.setContext(value: appContext, key: "app")
        }
        if let osContext {
            SentrySDKInternal.currentHub().scope.setContext(value: osContext, key: "os")
        }
    }

    private func assertPerThread(exceptionType: String, exceptionValue: String, exceptionMechanism: String, handled: Bool = true) throws {
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertEqual(1, scope?.attachments.count)

            XCTAssertEqual(callStackTreePerThread.callStacks.count, event?.threads?.count)
            XCTAssertEqual(timeStampBegin, event?.timestamp)

            try assertFrames(event: event, exceptionType, exceptionValue, exceptionMechanism, framesCount: 3, handled: handled)
        }
    }

    private func assertNothingCaptured() {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }

        XCTAssertEqual(0, client.captureEventWithScopeInvocations.count, "No events should be captured")
    }

    private func assertNotPerThread(exceptionType: String, exceptionValue: String, exceptionMechanism: String) throws {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }

        let invocations = client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(1, invocations.count, "Client expected to capture 1 event.")
    }

    private func assertFrames(event: Event?, _ exceptionType: String, _ exceptionValue: String, _ exceptionMechanism: String, framesCount: Int, handled: Bool = true, debugMetaCount: Int = 2) throws {
        let sentryFrames = try XCTUnwrap(event?.threads?.first?.stacktrace?.frames, "Event has no frames.")
        XCTAssertEqual(framesCount, sentryFrames.count)

        XCTAssertEqual(1, event?.exceptions?.count)
        let exception = try XCTUnwrap(event?.exceptions?.first, "Event has exception.")

        XCTAssertEqual(exceptionType, exception.type)
        XCTAssertEqual(exceptionValue, exception.value)
        XCTAssertEqual(exceptionMechanism, exception.mechanism?.type)
        XCTAssertEqual(handled, exception.mechanism?.handled?.boolValue)
        XCTAssertEqual(true, exception.mechanism?.synthetic)
        XCTAssertEqual(event?.threads?.first?.threadId, exception.threadId)

        XCTAssertEqual(debugMetaCount, event?.debugMeta?.count)
        guard let debugMeta = event?.debugMeta else {
            XCTFail("Event has no debugMeta.")
            return
        }

        XCTAssertEqual("macho", try XCTUnwrap(debugMeta.first).type)
        XCTAssertEqual("9E8D8DE6-EEC1-3199-8720-9ED68EE3F967", try XCTUnwrap(debugMeta.first).debugID)
        XCTAssertEqual("0x000000010109c000", try XCTUnwrap(debugMeta.first).imageAddress)
        XCTAssertEqual("Sentry", try XCTUnwrap(debugMeta.first).codeFile)

        XCTAssertEqual("macho", try XCTUnwrap(debugMeta.element(at: 1)).type)
        XCTAssertEqual("CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF", try XCTUnwrap(debugMeta.element(at: 1)).debugID)
        XCTAssertEqual("0x0000000100f3c000", try XCTUnwrap(debugMeta.element(at: 1)).imageAddress)
        XCTAssertEqual("iOS-Swift", try XCTUnwrap(debugMeta.element(at: 1)).codeFile)
    }

    private func assertFrame(mxFrame: SentryMXFrame, sentryFrame: Frame) {
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)

        let lastRootFrameAddress = formatHexAddress(value: mxFrame.address)
        XCTAssertEqual(lastRootFrameAddress, sentryFrame.instructionAddress)

        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        let lastRootFrameImageAddress = formatHexAddress(value: mxFrame.address - UInt64(mxFrame.offsetIntoBinaryTextSegment))
        XCTAssertEqual(lastRootFrameImageAddress, sentryFrame.imageAddress)

        XCTAssertFalse(sentryFrame.inApp as? Bool ?? true)
    }

}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCallStackTree: MXCallStackTree {
    struct Override {
        var jsonRepresentation = Data()
    }

    public var overrides = Override()

    override func jsonRepresentation() -> Data {
        return overrides.jsonRepresentation
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCrashDiagnostic: MXCrashDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
        var exceptionType: NSNumber?
        var exceptionCode: NSNumber?
        var signal: NSNumber?
    }

    public var overrides = Override()

    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }

    override var exceptionType: NSNumber? {
        return overrides.exceptionType
    }

    override var exceptionCode: NSNumber? {
        return overrides.exceptionCode
    }

    override var signal: NSNumber? {
        return overrides.signal
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCPUExceptionDiagnostic: MXCPUExceptionDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }

    public var overrides = Override()

    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }

    override var totalCPUTime: Measurement<UnitDuration> {
        return Measurement(value: 2.2, unit: .milliseconds)
    }

    override var totalSampledTime: Measurement<UnitDuration> {
        return Measurement(value: 5.5, unit: .milliseconds)
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDiskWriteExceptionDiagnostic: MXDiskWriteExceptionDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }

    public var overrides = Override()

    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }

    override var totalWritesCaused: Measurement<UnitInformationStorage> {
        return Measurement(value: 5.5, unit: .mebibits)
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXHangDiagnostic: MXHangDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
        var hangDuration = Measurement(value: 6.6, unit: UnitDuration.seconds)
        var jsonRepresentation: Data?
        var metaData: MXMetaData?
        var applicationVersion: String?
    }

    public var overrides = Override()
    let jsonRepresentationInvocations = Invocations<Void>()

    override func jsonRepresentation() -> Data {
        jsonRepresentationInvocations.record(())
        return overrides.jsonRepresentation ?? super.jsonRepresentation()
    }

    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }

    override var hangDuration: Measurement<UnitDuration> {
        return overrides.hangDuration
    }

    override var metaData: MXMetaData {
        return overrides.metaData ?? super.metaData
    }

    override var applicationVersion: String {
        return overrides.applicationVersion ?? super.applicationVersion
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXMetaData: MXMetaData {
    struct Override {
        var osVersion = ""
        var applicationBuildVersion = ""
    }

    public var overrides = Override()

    override var osVersion: String {
        return overrides.osVersion
    }

    override var applicationBuildVersion: String {
        return overrides.applicationBuildVersion
    }
}

#endif // os(iOS) || os(macOS)
