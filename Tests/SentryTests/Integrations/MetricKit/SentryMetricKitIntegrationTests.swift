@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {

    var callStackTreePerThread: SentryMXCallStackTree!
    var timeStampBegin: Date!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let contentsPerThread = try contentsOfResource("MetricKitCallstacks/per-thread")
        callStackTreePerThread = try JSONDecoder().decode(SentryMXCallStackTree.self, from: contentsPerThread)

        timeStampBegin = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(21.23)
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testDidReceive_whenCrashDiagnosticHasExceptionInfo_shouldFormatExceptionValue() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        let crashDiagnostic = TestMXCrashDiagnostic()
        crashDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        crashDiagnostic.overrides.exceptionType = 1
        crashDiagnostic.overrides.exceptionCode = 0
        crashDiagnostic.overrides.signal = 11
        let payload = TestMXDiagnosticPayload()
        payload.overrides.crashDiagnostics = [crashDiagnostic]

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

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
            diagnosticCapturer: SentryMXDiagnosticCapturer(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                attachDiagnosticAsAttachment: false,
                enabledDiagnostics: [.crash],
                processStartDate: .distantPast
            )
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
            diagnosticCapturer: SentryMXDiagnosticCapturer(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                attachDiagnosticAsAttachment: false,
                enabledDiagnostics: [.crash],
                processStartDate: .distantPast
            )
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

    func testDidReceive_whenDiagnosticPayloadsAreNotReceived_shouldNotCaptureEvent() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = SentryMXManager(
            diagnosticCapturer: SentryMXDiagnosticCapturer(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                attachDiagnosticAsAttachment: false,
                enabledDiagnostics: [.hang],
                processStartDate: .distantPast
            ),
            receivesDiagnosticPayloads: false
        )
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [hangDiagnostic]

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        assertNothingCaptured()
    }

    func testInit_whenDiagnosticsEnabled_shouldReceiveDiagnosticsFromMetricManagerOnlyOnXOS27() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.hang]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer { sut.uninstall() }

        // -- Assert --
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), Self.isBuiltWithMetricManager {
            XCTAssertNotNil(sut.metricManager)
            XCTAssertFalse(sut.mxManager.receivesDiagnosticPayloads)
        } else {
            XCTAssertNil(sut.metricManager)
            XCTAssertTrue(sut.mxManager.receivesDiagnosticPayloads)
        }
    }

    func testInit_whenOnlyMetricReportsEnabled_shouldReceiveDiagnosticPayloadsWithoutMetricManager() throws {
        // -- Arrange --
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = false
        #endif // !SDK_V10
        options.experimental.metrickit.enabledMetricReports = [.cpuCumulativeTime]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer { sut.uninstall() }

        // -- Assert --
        XCTAssertNil(sut.metricManager)
        XCTAssertTrue(sut.mxManager.receivesDiagnosticPayloads)
    }

    func testAttachDiagnosticAsAttachment() throws {
            givenSDKWithHubWithScope()

        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.enableMetricKitRawPayload = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.process(diagnosticPayloads: [payload])

            try assertEventWithScopeCaptured { _, _, _ in
                let diagnosticAttachment = try capturedHintAttachments().first { $0.filename == "MXDiagnosticPayload.json" }

                let attachmentJSON = try JSONSerialization.jsonObject(with: XCTUnwrap(diagnosticAttachment?.data)) as? NSDictionary
                let diagnosticJSON = try JSONSerialization.jsonObject(with: hangDiagnostic.jsonRepresentation()) as? NSDictionary
                XCTAssertEqual(attachmentJSON, diagnosticJSON)
            }
    }

    func testDidReceive_whenRawDiagnosticIsPrettyPrinted_shouldAttachCompactJSON() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = SentryMXManager(
            diagnosticCapturer: SentryMXDiagnosticCapturer(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                attachDiagnosticAsAttachment: true,
                enabledDiagnostics: [.hang],
                processStartDate: .distantPast
            )
        )
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        diagnostic.overrides.jsonRepresentation = Data("{\n  \"hangDuration\": \"6.6 sec\"\n}".utf8)
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { _, _, _ in
            let attachment = try XCTUnwrap(capturedHintAttachments().first { $0.filename == "MXDiagnosticPayload.json" })
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
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = Data(#"{"callStacks":"unexpected"}"#.utf8)
        let rawDiagnostic = Data(#"{"hangDuration":"6.6 sec","callStackTree":{"callStacks":"unexpected"}}"#.utf8)
        diagnostic.overrides.jsonRepresentation = rawDiagnostic
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
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
            let attachments = try capturedHintAttachments().filter { $0.filename == "MXDiagnosticPayload.json" }
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
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = Data(#"{"callStacks":"unexpected"}"#.utf8)
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

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
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

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
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let captures = client.captureEventWithScopeAndHintInvocations.invocations
        XCTAssertEqual(captures.count, 2)
        let malformedCapture = try XCTUnwrap(captures.first)
        let validCapture = try XCTUnwrap(captures.element(at: 1))
        XCTAssertNil(malformedCapture.event.threads)
        XCTAssertNil(malformedCapture.event.exceptions?.first?.stacktrace)
        let validFrames = try XCTUnwrap(validCapture.event.exceptions?.first?.stacktrace?.frames)
        XCTAssertFalse(validFrames.isEmpty)

        for (capture, expectedJSON) in [(malformedCapture, malformedJSON), (validCapture, validJSON)] {
            XCTAssertEqual(capture.event.timestamp, timeStampBegin)
            let attachments = capture.hint?.attachments.filter { $0.filename == "MXDiagnosticPayload.json" } ?? []
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
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.process(diagnosticPayloads: [payload])

            try assertEventWithScopeCaptured { _, _, _ in
                let diagnosticAttachment = try capturedHintAttachments().first { $0.filename == "MXDiagnosticPayload.json" }

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
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.process(diagnosticPayloads: [payload])

            try assertEventWithScopeCaptured { event, _, _ in
                let stacktrace = try XCTUnwrap( event?.threads?.first?.stacktrace)

                let inAppFramesCount = stacktrace.frames.filter { $0.inApp as? Bool ?? false }.count

                XCTAssertEqual(2, inAppFramesCount)
            }
    }

    func testDidReceive_whenCPUExceptionDiagnostic_shouldCaptureMostSampledStack() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        let cpuException = TestMXCPUExceptionDiagnostic()
        cpuException.overrides.callStackTree = callStackTree
        payload.overrides.cpuDiagnostic = [cpuException]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 1)
        let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first?.event)
        XCTAssertEqual(event.timestamp, timeStampBegin)
        XCTAssertEqual(event.level, .warning)

        XCTAssertEqual(event.exceptions?.count, 1)
        let exception = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(exception.type, "MXCPUException")
        XCTAssertEqual(exception.value, "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms")
        XCTAssertEqual(exception.mechanism?.type, "mx_cpu_exception")
        XCTAssertEqual(exception.mechanism?.handled, true)
        XCTAssertEqual(exception.mechanism?.synthetic, true)
        XCTAssertEqual(exception.threadId, 0)

        // The call stack isn't per thread, so all samples are aggregated into one thread holding
        // the most sampled stack. Sentry -> iOS-Swift -> iOS-Swift has 2 samples, every other stack 1.
        XCTAssertEqual(event.threads?.count, 1)
        let thread = try XCTUnwrap(event.threads?.first)
        XCTAssertEqual(thread.threadId, 0)
        XCTAssertEqual(thread.crashed, false)
        XCTAssertEqual(exception.stacktrace?.frames, thread.stacktrace?.frames)

        let frames = try XCTUnwrap(thread.stacktrace?.frames)
        XCTAssertEqual(frames.map(\.package), ["Sentry", "iOS-Swift", "iOS-Swift"])
        XCTAssertEqual(frames.map(\.instructionAddress), ["0x000000010110140c", "0x0000000100f4752c", "0x0000000100f474fa"])
        XCTAssertEqual(frames.map(\.imageAddress), ["0x000000010109c000", "0x0000000100f3c000", "0x0000000100f3bfd8"])
        XCTAssertEqual(frames.map(\.inApp), [false, false, false])

        let debugMeta = try XCTUnwrap(event.debugMeta)
        XCTAssertEqual(debugMeta.map(\.type), ["macho", "macho", "macho", "macho"])
        XCTAssertEqual(debugMeta.map(\.codeFile), ["Sentry", "iOS-Swift", "libswiftCore.dylib", "libsystem_pthread.dylib"])
        XCTAssertEqual(debugMeta.map(\.debugID), [
            "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967",
            "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF",
            "56C020FC-0369-3775-B947-148F388A65B3",
            "45AC734E-6649-3EE2-A096-3FD66441AB78"
        ])
        XCTAssertEqual(debugMeta.map(\.imageAddress), ["0x000000010109c000", "0x0000000100f3c000", "0x000000018d51a001", "0x00000001e19cc000"])
    }

    func testCPUExceptionDiagnostic_OnlyOneFrame() throws {
            givenSDKWithHubWithScope()

            let options = Options()
            #if !SDK_V10
            options.enableMetricKit = true
            #endif // !SDK_V10
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let cpuException = TestMXCPUExceptionDiagnostic()
        cpuException.overrides.callStackTree = callStackTree
        payload.overrides.cpuDiagnostic = [cpuException]
        payload.overrides.timeStampBegin = timeStampBegin
        sut.mxManager.process(diagnosticPayloads: [payload])

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

    func testDidReceive_whenDiskWriteExceptionDiagnostic_shouldCaptureMostSampledStack() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let diskWriteException = TestMXDiskWriteExceptionDiagnostic()
        diskWriteException.overrides.callStackTree = callStackTree
        payload.overrides.diskWriteDiagnostic = [diskWriteException]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 1)
        let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first?.event)
        XCTAssertEqual(event.timestamp, timeStampBegin)
        XCTAssertEqual(event.level, .warning)

        XCTAssertEqual(event.exceptions?.count, 1)
        let exception = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(exception.type, "MXDiskWriteException")
        XCTAssertEqual(exception.value, "MXDiskWriteException totalWritesCaused:5.5 Mib")
        XCTAssertEqual(exception.mechanism?.type, "mx_disk_write_exception")
        XCTAssertEqual(exception.mechanism?.handled, true)
        XCTAssertEqual(exception.mechanism?.synthetic, true)
        XCTAssertEqual(exception.threadId, 0)

        // Both root frames are the same frame, so they collapse into one stack.
        XCTAssertEqual(event.threads?.count, 1)
        let thread = try XCTUnwrap(event.threads?.first)
        XCTAssertEqual(thread.threadId, 0)
        XCTAssertEqual(thread.crashed, false)
        XCTAssertEqual(exception.stacktrace?.frames, thread.stacktrace?.frames)

        let frames = try XCTUnwrap(thread.stacktrace?.frames)
        XCTAssertEqual(frames.count, 1)
        let frame = try XCTUnwrap(frames.first)
        XCTAssertEqual(frame.package, "libsystem_pthread.dylib")
        XCTAssertEqual(frame.instructionAddress, "0x000000021f1a1a04")
        XCTAssertEqual(frame.imageAddress, "0x000000021f1a0001")
        XCTAssertEqual(frame.inApp, false)

        XCTAssertEqual(event.debugMeta?.count, 1)
        let debugImage = try XCTUnwrap(event.debugMeta?.first)
        XCTAssertEqual(debugImage.type, "macho")
        XCTAssertEqual(debugImage.debugID, "810E428A-F26D-37BB-BB0F-609CBB4718C7")
        XCTAssertEqual(debugImage.codeFile, "libsystem_pthread.dylib")
        XCTAssertEqual(debugImage.imageAddress, "0x000000021f1a0001")
    }

    func testDidReceive_whenHangDiagnostic_shouldCaptureEveryFrameWithTreeData() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let hangDiagnostic = TestMXHangDiagnostic()
        hangDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.hangDiagnostic = [hangDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 1)
        let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first?.event)
        XCTAssertEqual(event.timestamp, timeStampBegin)
        // Hangs longer than 500 ms are reported as errors.
        XCTAssertEqual(event.level, .error)

        XCTAssertEqual(event.exceptions?.count, 1)
        let exception = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(exception.type, "MXHangDiagnostic")
        XCTAssertEqual(exception.value, "MXHangDiagnostic hangDuration:6.6 sec")
        XCTAssertEqual(exception.mechanism?.type, "mx_hang_diagnostic")
        XCTAssertEqual(exception.mechanism?.handled, true)
        XCTAssertEqual(exception.mechanism?.synthetic, true)
        XCTAssertEqual(exception.threadId, 0)

        // Legacy hang reporting keeps every frame of the tree instead of the most sampled stack.
        XCTAssertEqual(event.threads?.count, 1)
        let thread = try XCTUnwrap(event.threads?.first)
        XCTAssertEqual(thread.threadId, 0)
        XCTAssertEqual(thread.crashed, false)
        XCTAssertEqual(exception.stacktrace?.frames, thread.stacktrace?.frames)

        let frames = try XCTUnwrap(thread.stacktrace?.frames)
        XCTAssertEqual(frames.map(\.package), ["libsystem_pthread.dylib", "libsystem_pthread.dylib"])
        XCTAssertEqual(frames.map(\.instructionAddress), ["0x000000021f1a1a04", "0x000000021f1a1a04"])
        XCTAssertEqual(frames.map(\.imageAddress), ["0x000000021f1a0001", "0x000000021f1a0001"])
        XCTAssertEqual(frames.map(\.inApp), [false, false])
        XCTAssertEqual(frames.map(\.parentIndex), [-1, -1])
        XCTAssertEqual(frames.map(\.sampleCount), [92, 92])

        XCTAssertEqual(event.debugMeta?.count, 1)
        let debugImage = try XCTUnwrap(event.debugMeta?.first)
        XCTAssertEqual(debugImage.type, "macho")
        XCTAssertEqual(debugImage.debugID, "810E428A-F26D-37BB-BB0F-609CBB4718C7")
        XCTAssertEqual(debugImage.codeFile, "libsystem_pthread.dylib")
        XCTAssertEqual(debugImage.imageAddress, "0x000000021f1a0001")
    }

    func testHangDiagnostic_shouldSetLevelBasedOnDuration() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

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
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let invocations = client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(4, invocations.count)
        XCTAssertEqual([.warning, .warning, .error, .error], invocations.map(\.event.level))
    }

#if os(iOS) || os(visionOS)
    func testDidReceive_whenAppLaunchDiagnosticEnabled_shouldCaptureEvent() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("MXAppLaunchDiagnostic requires iOS 16")
        }

        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.appLaunch]
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let appLaunchDiagnostic = TestMXAppLaunchDiagnostic()
        appLaunchDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.appLaunchDiagnostics = [appLaunchDiagnostic]
        payload.overrides.timeStampBegin = timeStampBegin

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        try assertPerThread(exceptionType: "MXAppLaunchDiagnostic", exceptionValue: "MXAppLaunchDiagnostic launchDuration:3.3 sec", exceptionMechanism: "mx_app_launch_diagnostic")
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        XCTAssertEqual(client.captureEventWithScopeInvocations.first?.event.level, .warning)
    }

    func testDidReceive_whenAppLaunchDiagnosticNotEnabled_shouldNotCaptureEvent() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("MXAppLaunchDiagnostic requires iOS 16")
        }

        // -- Arrange --
        givenSDKWithHubWithScope()
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.hang]
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        let payload = TestMXDiagnosticPayload()
        let callStackTree = TestMXCallStackTree()
        callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let appLaunchDiagnostic = TestMXAppLaunchDiagnostic()
        appLaunchDiagnostic.overrides.callStackTree = callStackTree
        payload.overrides.appLaunchDiagnostics = [appLaunchDiagnostic]

        // -- Act --
        sut.mxManager.process(diagnosticPayloads: [payload])

        // -- Assert --
        assertNothingCaptured()
    }
#endif // os(iOS) || os(visionOS)

    /// Whether the SDK was built with an SDK that has `MetricManager`, which Xcode 27 added.
    private static var isBuiltWithMetricManager: Bool {
        #if compiler(>=6.4)
        return true
        #else
        return false
        #endif // compiler(>=6.4)
    }

    private func capturedHintAttachments() throws -> [Attachment] {
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        XCTAssertEqual(client.captureEventWithScopeAndHintInvocations.count, 1, "Expected exactly one event captured with a hint.")
        let capture = try XCTUnwrap(client.captureEventWithScopeAndHintInvocations.first)
        return capture.hint?.attachments ?? []
    }

    private func givenSDKWithHubWithScope() {
        let scope = Scope()
        scope.addBreadcrumb(TestData.crumb)
        scope.addAttachment(TestData.dataAttachment)

        givenSdkWithHub(scope: scope)
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

#if os(iOS) || os(visionOS)
@available(iOS 16.0, *)
class TestMXAppLaunchDiagnostic: MXAppLaunchDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
        var launchDuration = Measurement(value: 3.3, unit: UnitDuration.seconds)
    }

    public var overrides = Override()

    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }

    override var launchDuration: Measurement<UnitDuration> {
        return overrides.launchDuration
    }
}
#endif // os(iOS) || os(visionOS)

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXMetaData: MXMetaData {
    struct Override {
        var osVersion = ""
        var applicationBuildVersion = ""
        var pid: pid_t = 0
    }

    public var overrides = Override()

    override var osVersion: String {
        return overrides.osVersion
    }

    @available(iOS 17.0, macOS 14.0, *)
    override var pid: pid_t {
        return overrides.pid
    }

    override var applicationBuildVersion: String {
        return overrides.applicationBuildVersion
    }
}

#endif // os(iOS) || os(macOS)
