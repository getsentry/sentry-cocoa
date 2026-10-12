#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

final class TestSDKModuleBoundaryTests: XCTestCase {
    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    func testClientAccessors_whenImported_shouldReturnRealDependencies() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(TestClient(options: options))

        // -- Act --
        let actualOptions = client.options
        let fileManager = client.fileManager

        // -- Assert --
        XCTAssertIdentical(actualOptions, options)
        XCTAssertIdentical(fileManager, Dynamic(client).fileManager.asObject as? SentryFileManager)
        actualOptions.tracesSampleRate = 0.25
        XCTAssertEqual((client.getOptions() as? Options)?.tracesSampleRate, 0.25)
    }

    func testHubSession_whenAssignedAndCleared_shouldUseRealSessionProperty() {
        // -- Arrange --
        let hub = TestHub(client: nil, andScope: nil)
        let session = SentrySession(releaseName: "test", distinctId: "user")

        // -- Act --
        hub.session = session

        // -- Assert --
        XCTAssertIdentical(hub.session, session)
        XCTAssertIdentical(Dynamic(hub).session.asObject as? SentrySession, session)
        hub.session = nil
        XCTAssertNil(hub.session)
        XCTAssertNil(Dynamic(hub).session.asObject)
    }

    func testTransactionInitializers_whenImported_shouldPreserveSamplingAndIdentity() throws {
        // -- Arrange --
        let traceId = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()

        // -- Act --
        let basic = TransactionContext(name: "basic", nameSource: .url, operation: "http", origin: "manual")
        let sampled = TransactionContext(name: "sampled", nameSource: .route, operation: "http", origin: "manual", sampled: .yes, sampleRate: 0.25, sampleRand: 0.125)
        let parent = TransactionContext(name: "parent", nameSource: .component, operation: "ui.load", origin: "manual", trace: traceId, spanId: spanId, parentSpanId: parentId, parentSampled: .no, parentSampleRate: 0.5, parentSampleRand: 0.75)
        let full = TransactionContext(name: "full", nameSource: .custom, operation: "ui.load", origin: "manual", trace: traceId, spanId: spanId, parentSpanId: parentId, sampled: .yes, parentSampled: .no, sampleRate: 0.25, parentSampleRate: 0.5, sampleRand: 0.125, parentSampleRand: 0.75)

        // -- Assert --
        XCTAssertEqual(basic.nameSource, .url)
        XCTAssertEqual(basic.name, "basic")
        XCTAssertEqual(basic.operation, "http")
        XCTAssertEqual(basic.origin, "manual")
        XCTAssertEqual(sampled.nameSource, .route)
        XCTAssertEqual(sampled.sampled, .yes)
        XCTAssertEqual(sampled.sampleRate, 0.25)
        XCTAssertEqual(sampled.sampleRand, 0.125)
        XCTAssertEqual(parent.nameSource, .component)
        XCTAssertEqual(parent.traceId, traceId)
        XCTAssertEqual(parent.spanId, spanId)
        XCTAssertEqual(parent.parentSpanId, parentId)
        XCTAssertEqual(parent.parentSampled, .no)
        XCTAssertEqual(parent.parentSampleRate, 0.5)
        XCTAssertEqual(parent.parentSampleRand, 0.75)
        XCTAssertEqual(full.nameSource, .custom)
        XCTAssertEqual(full.traceId, traceId)
        XCTAssertEqual(full.spanId, spanId)
        XCTAssertEqual(full.parentSpanId, parentId)
        XCTAssertEqual(full.sampled, .yes)
        XCTAssertEqual(full.parentSampled, .no)
        XCTAssertEqual(full.sampleRate, 0.25)
        XCTAssertEqual(full.parentSampleRate, 0.5)
        XCTAssertEqual(full.sampleRand, 0.125)
        XCTAssertEqual(full.parentSampleRand, 0.75)
    }

    func testFatalEventWithSession_whenOverridden_shouldDispatchThroughWrapper() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
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

    func testScopeAccess_whenAssigned_shouldUseRealPropagationContextAndSession() throws {
        // -- Arrange --
        let scope = Scope()
        let context = SentryPropagationContext()
        let session = SentrySession(releaseName: "test", distinctId: "user")
        scope.setEnvironment("scope-environment")

        // -- Act --
        scope.propagationContext = context
        scope.applyTo(session: session)

        // -- Assert --
        XCTAssertIdentical(scope.propagationContext, context)
        XCTAssertIdentical(Dynamic(scope).propagationContext.asObject as? SentryPropagationContext, context)
        XCTAssertEqual(session.environment, "scope-environment")
    }

    func testTraceContextInitializers_whenImported_shouldPreserveValuesAndNilResult() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        options.releaseName = "test-release"
        let scope = Scope()
        let context = TransactionContext(name: "transaction", nameSource: .custom, operation: "test", origin: "manual")
        let tracer = SentryTracer(transactionContext: context, hub: nil)

        // -- Act --
        let emptyScopeResult = TraceContext(scope: scope, options: options)
        scope.span = tracer
        let fromScope = try XCTUnwrap(TraceContext(scope: scope, options: options))
        let fromTracer = try XCTUnwrap(TraceContext(tracer: tracer, scope: scope, options: options))
        let fromTrace = TraceContext(trace: context.traceId, options: options, replayId: "replay")

        // -- Assert --
        XCTAssertNil(emptyScopeResult)
        XCTAssertEqual(fromScope.traceId, context.traceId)
        XCTAssertEqual(fromTracer.traceId, context.traceId)
        XCTAssertEqual(fromTrace.traceId, context.traceId)
        XCTAssertEqual(fromScope.releaseName, options.releaseName)
        XCTAssertEqual(fromTracer.transaction, "transaction")
        XCTAssertEqual(fromTrace.replayId, "replay")
    }

    func testSDKOptions_whenSetAndCleared_shouldReturnRealOptions() throws {
        // -- Arrange --
        let options = Options.noIntegrations()

        // -- Act --
        SentrySDKInternal.setStart(with: options)

        // -- Assert --
        XCTAssertIdentical(SentrySDKInternal.options, options)
        SentryDependencyContainer.sharedInstance().startOptions = nil
        XCTAssertNil(SentrySDKInternal.options)
    }

    func testReplayCapture_whenCalledThroughHub_shouldDispatchThroughWrapper() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
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

    func testSessionDelegate_whenCapturingError_shouldCallSwiftOverride() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let container = SentryDependencyContainer.sharedInstance()
        let queue = TestSentryDispatchQueueWrapper()
        let fileManager = try TestFileManager(options: options, dateProvider: container.dateProvider, dispatchQueueWrapper: queue)
        let transport = TestTransportAdapter(transports: [TestTransport()], options: options)
        let client = SentryClientInternal(
            options: options,
            dateProvider: container.dateProvider,
            transportAdapter: transport,
            fileManager: fileManager,
            threadInspector: SentryDefaultThreadInspector(options: options),
            debugImageProvider: container.debugImageProvider,
            random: TestRandom(value: 0.5),
            locale: Locale(identifier: "en_US"),
            timezone: .current,
            eventContextEnricher: TestEventContextEnricher(),
            binaryImageCache: container.binaryImageCache,
            dispatchQueueWrapper: queue
        )
        let delegate = SessionDelegate()
        client.sessionDelegate = delegate

        // -- Act --
        client.capture(error: NSError(domain: "test", code: -1), scope: Scope())

        // -- Assert --
        XCTAssertEqual(delegate.invocations, 1)
        XCTAssertIdentical(Dynamic(client).sessionDelegate.asObject as? SessionDelegate, delegate)
    }

    func testClientFileManager_whenReplaced_shouldUpdateRealDependency() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(TestClient(options: options))
        let fileManager = try TestFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

        // -- Act --
        client.fileManager = fileManager

        // -- Assert --
        XCTAssertIdentical(client.fileManager, fileManager)
        XCTAssertIdentical(Dynamic(client).fileManager.asObject as? SentryFileManager, fileManager)
    }

    func testTracerMeasurements_whenRecorded_shouldPreserveValueAndUnit() throws {
        // -- Arrange --
        let context = TransactionContext(name: "measurements", nameSource: .custom, operation: "test", origin: "manual")
        let tracer = SentryTracer(transactionContext: context, hub: nil)

        // -- Act --
        tracer.setMeasurement(name: "display", value: 42, unit: MeasurementUnitDuration.millisecond)
        let measurements = tracer.measurements

        // -- Assert --
        XCTAssertEqual(measurements.count, 1)
        let measurement = try XCTUnwrap(measurements["display"])
        XCTAssertEqual(measurement.value, 42)
        XCTAssertEqual(measurement.unit?.unit, "millisecond")
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

    func testDelayedFramesInitializer_whenInjected_shouldUseGivenDateProvider() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()

        // -- Act --
        let tracker = TestDelayedWrapper(keepDelayedFramesDuration: 10, dateProvider: dateProvider)
        tracker.reset()

        // -- Assert --
        XCTAssertIdentical(tracker.value(forKey: "dateProvider") as? TestCurrentDateProvider, dateProvider)
        XCTAssertEqual(tracker.value(forKey: "keepDelayedFramesDuration") as? Double, 10)
    }
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
