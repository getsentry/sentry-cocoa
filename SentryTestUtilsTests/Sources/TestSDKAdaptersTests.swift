#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

// Only exercise interoperability risks here; SDK behavior is covered by the main suites.
final class TestSDKAdaptersTests: XCTestCase {
    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    func testClientAccessors_whenUsingOriginalAPI_shouldPreserveInjectedObjects() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)
        let client = try XCTUnwrap(TestClient(options: options))
        let container = SentryDependencyContainer.sharedInstance()
        let fileManager = try TestFileManager(options: options, dateProvider: container.dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let replacementOptions = Options.noIntegrations()

        // -- Act --
        client.fileManager = fileManager
        client.options = replacementOptions

        // -- Assert --
        XCTAssertIdentical(client.fileManager, fileManager)
        XCTAssertIdentical(client.options, replacementOptions)
    }

    func testScopeAccessors_whenUsingOriginalAPI_shouldPreservePropagationContext() {
        // -- Arrange --
        let scope = Scope()
        let context = SentryPropagationContext()

        // -- Act --
        // Initializer expressions must also resolve without an ambiguous ObjC property overload.
        scope.propagationContext = SentryPropagationContext(traceId: context.traceId, spanId: context.spanId)
        let traceId = scope.propagationContext.traceId
        scope.propagationContext = context

        // -- Assert --
        XCTAssertEqual(traceId, context.traceId)
        XCTAssertIdentical(scope.propagationContext, context)
        XCTAssertEqual(scope.propagationContext.traceId, scope.propagationContextTraceId)
    }

    func testTracingAccessors_whenUsingOriginalAPI_shouldPreserveTypedValues() {
        // -- Arrange --
        let context = TransactionContext(name: "test", nameSource: .custom, operation: "test", origin: "manual")
        let tracer = SentryTracer(transactionContext: context, hub: nil)

        // -- Act --
        tracer.setMeasurement(name: "duration", value: 12, unit: MeasurementUnitDuration.millisecond)
        let measurements: [String: SentryMeasurementValue] = tracer.measurements
        let nameSource: SentryTransactionNameSource = context.nameSource

        // -- Assert --
        XCTAssertEqual(nameSource, .custom)
        XCTAssertEqual(measurements["duration"]?.value, 12)
        XCTAssertEqual(measurements["duration"]?.unit?.unit, "millisecond")
    }

    func testHubSession_whenUsingOriginalAPI_shouldPreserveSessionAndNil() {
        // -- Arrange --
        let hub = SentryHubInternal(client: nil, andScope: Scope())
        let session = SentrySession(releaseName: "test", distinctId: "user")

        // -- Act --
        hub.session = session

        // -- Assert --
        XCTAssertIdentical(hub.session, session)
        hub.session = nil
        XCTAssertNil(hub.session)
    }

    func testDSN_whenUsingTestIdentifier_shouldNotRequireAutomaticEncoding() throws {
        // -- Arrange --
        let dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)

        // -- Act --
        // Older Foundation versions reject invalid URL characters instead of encoding them.
        if #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) {
            let url = URL(string: dsn, encodingInvalidCharacters: false)

            // -- Assert --
            XCTAssertNotNil(url)
        }
        XCTAssertNoThrow(try SentryDsn(string: dsn))
    }

    func testSDKAccessors_whenUsingOriginalAPI_shouldPreserveOptionsAndEnvelopeDispatch() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: Scope()))
        let envelope = SentryEnvelope(event: Event())

        // -- Act --
        SentrySDKInternal.setStart(with: options)
        SentrySDKInternal.capture(envelope)
        SentrySDKInternal.store(envelope)

        // -- Assert --
        XCTAssertIdentical(SentrySDKInternal.options, options)
        XCTAssertEqual(client.captureEnvelopeInvocations.count, 1)
        XCTAssertEqual(client.storedEnvelopeInvocations.count, 1)
        SentrySDKInternal.setStart(with: nil)
        XCTAssertNil(SentrySDKInternal.options)
    }

    func testFatalEventWithSession_whenOverridden_shouldDispatchThroughWrapper() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)
        let client = try XCTUnwrap(SessionCaptureClient(options: options))
        let event = Event()
        let session = SentrySession(releaseName: "test", distinctId: "user")
        let scope = Scope()

        // -- Act --
        let eventId = client.captureFatalEvent(event, with: session, with: scope)

        // -- Assert --
        XCTAssertEqual(eventId, event.eventId)
        XCTAssertEqual(client.captureFatalEventWithSessionInvocations.count, 1)
        let invocation = try XCTUnwrap(client.captureFatalEventWithSessionInvocations.first)
        XCTAssertIdentical(invocation.event, event)
        XCTAssertIdentical(invocation.session, session)
        XCTAssertIdentical(invocation.scope, scope)
    }

    func testReplayCapture_whenCalledThroughHub_shouldCallSwiftOverride() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)
        let client = try XCTUnwrap(ReplayCaptureClient(options: options))
        let scope = Scope()
        let hub = SentryHubInternal(client: client, andScope: scope)
        let event = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 1)
        let recording = SentryReplayRecording(segmentId: 1, size: 200, start: Date(), duration: 1_000, frameCount: 1, frameRate: 1, height: 100, width: 100, extraEvents: [])
        let video = URL(fileURLWithPath: "/unused-test-video.mp4")

        // -- Act --
        hub.captureReplayEvent(event, replayRecording: recording, video: video)

        // -- Assert --
        XCTAssertIdentical(client.event, event)
        XCTAssertIdentical(client.recording, recording)
        XCTAssertEqual(client.video, video)
        XCTAssertIdentical(client.scope, scope)
    }

    func testReplayCapture_whenNotOverridden_shouldUseClientImplementation() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)
        var preparedEvent: Event?
        options.beforeSend = { event in
            preparedEvent = event
            return nil
        }
        let client = try XCTUnwrap(TestClient(options: options))
        let event = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 1)
        let recording = SentryReplayRecording(segmentId: 1, size: 200, start: Date(), duration: 1_000, frameCount: 1, frameRate: 1, height: 100, width: 100, extraEvents: [])

        // -- Act --
        client.capture(event, replayRecording: recording, video: URL(fileURLWithPath: "/unused-test-video.mp4"), with: Scope())

        // -- Assert --
        XCTAssertIdentical(preparedEvent, event)
    }

    func testSessionDelegate_whenCapturingError_shouldCallSwiftOverride() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: #function)
        let client = try XCTUnwrap(TestClient(options: options))
        let delegate = SessionDelegate()
        client.sessionDelegate = delegate

        // -- Act --
        _ = client.capture(error: NSError(domain: "test", code: -1), scope: Scope())

        // -- Assert --
        XCTAssertEqual(delegate.invocations, 1)
        XCTAssertIdentical(Dynamic(client).sessionDelegate.asObject as? SessionDelegate, delegate)
    }

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func testSpanInitializer_whenImported_shouldPreserveContextAndFrameTracker() {
        // -- Arrange --
        let context = SpanContext(operation: "test")
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker

        // -- Act --
        let span = SentrySpanInternal(context: context, framesTracker: framesTracker)
        let tracer = SentryTracer(context: context, framesTracker: nil)
        let subclass = ImportedSpan(context: context, framesTracker: nil)

        // -- Assert --
        XCTAssertEqual(span.traceId, context.traceId)
        XCTAssertEqual(span.spanId, context.spanId)
        XCTAssertEqual(span.operation, "test")
        XCTAssertIdentical(span.value(forKey: "framesTracker") as? SentryFramesTracker, framesTracker)
        XCTAssertEqual(tracer.traceId, context.traceId)
        XCTAssertNil(tracer.value(forKey: "framesTracker"))
        XCTAssertEqual(subclass.traceId, context.traceId)
    }

    // Swift subclasses must not inherit two names for the same Objective-C initializer.
    private final class ImportedSpan: SentrySpanInternal {}
    #endif

    private final class SessionDelegate: SentryTestSessionDelegateWrapper {
        var invocations = 0

        override func wrapper_incrementSessionErrors() -> Any? {
            invocations += 1
            return SentrySession(releaseName: "test", distinctId: "user")
        }
    }

    private final class ReplayCaptureClient: TestClient {
        var event: SentryReplayEvent?
        var recording: SentryReplayRecording?
        var video: URL?
        var scope: Scope?

        override func capture(_ event: Any, replayRecording recording: Any, video: URL, with scope: Scope) {
            self.event = event as? SentryReplayEvent
            self.recording = recording as? SentryReplayRecording
            self.video = video
            self.scope = scope
        }
    }

    private final class SessionCaptureClient: TestClient {
        override func wrapper_captureFatalEvent(_ event: Event, session: Any, scope: Scope) -> SentryId {
            _ = super.wrapper_captureFatalEvent(event, session: session, scope: scope)
            return event.eventId
        }
    }
}
