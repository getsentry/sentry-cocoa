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
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(TestClient(options: options))
        let container = SentryDependencyContainer.sharedInstance()
        let fileManager = try TestFileManager(options: options, dateProvider: container.dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let replacementOptions = Options.noIntegrations()

        // -- Act --
        // A nonthrowing closure checks source compatibility, not just runtime behavior.
        let access: () -> Void = {
            client.fileManager = fileManager
            client.options = replacementOptions

            // -- Assert --
            XCTAssertIdentical(client.fileManager, fileManager)
            XCTAssertIdentical(client.options, replacementOptions)
        }
        access()
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

    func testSDKAccessors_whenUsingOriginalAPI_shouldPreserveOptionsAndEnvelopeDispatch() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: Scope()))
        let envelope = SentryEnvelope(event: Event())

        // -- Act --
        let access: () -> Void = {
            SentrySDKInternal.setStart(with: options)
            SentrySDKInternal.capture(envelope)
            SentrySDKInternal.store(envelope)

            // -- Assert --
            XCTAssertIdentical(SentrySDKInternal.options, options)
        }
        access()
        XCTAssertEqual(client.captureEnvelopeInvocations.count, 1)
        XCTAssertEqual(client.storedEnvelopeInvocations.count, 1)
        SentrySDKInternal.setStart(with: nil)
        XCTAssertNil(SentrySDKInternal.options)
    }

    func testEnvelopeRateLimit_whenRateLimited_shouldForwardTypedDelegateCallback() throws {
        // -- Arrange --
        let limits = SentryDependencyContainer.sharedInstance().rateLimits
        let url = try XCTUnwrap(URL(string: "https://example.invalid"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "60"]))
        limits.update(response)
        let limiter = EnvelopeRateLimit(rateLimits: limits)
        let delegate = TestEnvelopeRateLimitDelegate()
        limiter.setDelegate(delegate)
        let item = SentryEnvelopeItem(event: Event())
        let envelope = SentryEnvelope(id: nil, singleItem: item)

        // -- Act --
        let result = limiter.removeRateLimitedItems(envelope)

        // -- Assert --
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(delegate.envelopeItemsDropped.invocations, [.error])
        XCTAssertIdentical(delegate.droppedItems.first, item)
    }

    func testEnvelopeRateLimit_whenDelegateReleased_shouldNotRetainDelegate() throws {
        // -- Arrange --
        let limits = SentryDependencyContainer.sharedInstance().rateLimits
        let url = try XCTUnwrap(URL(string: "https://example.invalid"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "60"]))
        limits.update(response)
        let limiter = EnvelopeRateLimit(rateLimits: limits)
        weak var weakDelegate: TestEnvelopeRateLimitDelegate?
        autoreleasepool {
            let delegate = TestEnvelopeRateLimitDelegate()
            weakDelegate = delegate
            limiter.setDelegate(delegate)
            XCTAssertNotNil(weakDelegate)
        }

        // -- Act --
        let result = limiter.removeRateLimitedItems(TestConstants.envelope)

        // -- Assert --
        XCTAssertNil(weakDelegate)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testEnvelopeDelegate_whenBridgeReceivesInvalidValues_shouldReportFailure() {
        // -- Arrange --
        let delegate = TestEnvelopeRateLimitDelegate()
        let item = SentryEnvelopeItem(event: Event())

        // -- Act --
        XCTExpectFailure("The erased bridge must reject invalid items") {
            delegate.wrapper_envelopeItemDropped(NSObject(), withCategory: SentryDataCategory.error.rawValue)
        }
        XCTExpectFailure("The erased bridge must reject invalid categories") {
            delegate.wrapper_envelopeItemDropped(item, withCategory: UInt.max)
        }

        // -- Assert --
        XCTAssertTrue(delegate.droppedItems.invocations.isEmpty)
        XCTAssertTrue(delegate.envelopeItemsDropped.invocations.isEmpty)
    }

    func testHttpTransport_whenCreatedThroughAdapter_shouldUseInjectedDependencies() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let container = SentryDependencyContainer.sharedInstance()
        let queue = TestSentryDispatchQueueWrapper()
        queue.dispatchAsyncExecutesBlock = false
        let fileManager = try TestFileManager(options: options, dateProvider: container.dateProvider, dispatchQueueWrapper: queue)
        let requests = UnavailableRequestManager()
        let reachability = container.reachability
        reachability.skipRegisteringActualCallbacks = true

        // -- Act --
        let transport = makeTestHttpTransport(
            dsn: try XCTUnwrap(options.parsedDsn),
            sendClientReports: false,
            cachedEnvelopeSendDelay: 0,
            dateProvider: container.dateProvider,
            fileManager: fileManager,
            requestManager: requests,
            requestBuilder: SentryNSURLRequestBuilder(),
            rateLimits: container.rateLimits,
            envelopeRateLimit: EnvelopeRateLimit(rateLimits: container.rateLimits),
            dispatchQueueWrapper: queue,
            reachability: reachability
        )

        // -- Assert --
        XCTAssertTrue(type(of: transport) == TestTransportFactory.httpTransportClass)
        XCTAssertIdentical(Dynamic(transport).requestManager.asObject as? UnavailableRequestManager, requests)
        XCTAssertIdentical(Dynamic(transport).fileManager.asObject as? SentryFileManager, fileManager)
        XCTAssertIdentical(Dynamic(transport).dispatchQueue.asObject as? SentryDispatchQueueWrapper, queue)
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

    private final class UnavailableRequestManager: NSObject, RequestManager {
        let isReady = false

        func add(_ request: URLRequest, completionHandler: SentryRequestOperationFinished?) {
            XCTFail("The adapter test must not send network requests")
        }
    }

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

        override func wrapper_captureReplayEvent(_ event: Any, recording: Any, video: URL, scope: Scope) {
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
