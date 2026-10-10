#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

// A wrong type is a broken bridge contract, not a recoverable SDK error. Keep that failure
// inside the test support instead of changing the SDK's nonthrowing APIs or inventing defaults.
// This intentionally terminates the test process on a contract violation.
func requireTestBridgeValue<Value>(_ value: Any, file: StaticString = #file, line: UInt = #line) -> Value {
    guard let typedValue = value as? Value else {
        let message = "Test bridge expected \(Value.self), got \(type(of: value))"
        XCTFail(message, file: file, line: line)
        preconditionFailure(message, file: file, line: line)
    }
    return typedValue
}

// Keep erased declarations distinct at the Clang boundary while preserving the typed SDK
// names used by tests. Calls still dispatch to the original Objective-C selectors.
extension SentryClientInternal {
    @_spi(Private) @nonobjc public convenience init(
        options: Options,
        dateProvider: SentryCurrentDateProvider,
        transportAdapter: SentryTransportAdapter,
        fileManager: SentryFileManager,
        threadInspector: SentryDefaultThreadInspector,
        debugImageProvider: SentryDebugImageProvider,
        random: SentryRandomProtocol,
        locale: Locale,
        timezone: TimeZone,
        eventContextEnricher: SentryEventContextEnricher,
        binaryImageCache: SentryBinaryImageCache,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        self.init(
            testOptions: options,
            dateProvider: dateProvider,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            threadInspector: threadInspector,
            debugImageProvider: debugImageProvider,
            random: random,
            locale: locale,
            timezone: timezone,
            eventContextEnricher: eventContextEnricher,
            binaryImageCache: binaryImageCache,
            dispatchQueueWrapper: dispatchQueueWrapper
        )
    }

    // Xcode imports these typed methods already; only SwiftPM needs the forwarding overloads.
    #if SWIFT_PACKAGE
    @_spi(Private) @nonobjc public func captureFatalEvent(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        test_captureFatalEvent(event, session: session, scope: scope)
    }

    @_spi(Private) @nonobjc public func capture(_ event: SentryReplayEvent, replayRecording: SentryReplayRecording, video: URL, with scope: Scope) {
        test_captureReplayEvent(event, recording: replayRecording, video: video, scope: scope)
    }

    @_spi(Private) @nonobjc public func store(_ envelope: SentryEnvelope) {
        test_storeEnvelope(envelope)
    }
    #endif

    // Xcode already imports the typed property. SwiftPM uses the SDK's existing ObjC bridge.
    #if SWIFT_PACKAGE
    public var options: Options {
        get { requireTestBridgeValue(getOptions()) }
        set { setOptions(newValue) }
    }
    #endif

    @_spi(Private) public var fileManager: SentryFileManager {
        get { requireTestBridgeValue(test_fileManager()) }
        set { test_setFileManager(newValue) }
    }
}

extension SentryHubInternal {
    @_spi(Private) @nonobjc public convenience init(
        client: SentryClientInternal?,
        andScope scope: Scope?,
        activeCrashReporterState: SentryCrashReporterState,
        andDispatchQueue dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.init(
            testClient: client,
            andScope: scope,
            activeCrashReporterState: activeCrashReporterState,
            andDispatchQueue: dispatchQueue
        )
    }

    @_spi(Private) @nonobjc public convenience init(
        client: SentryClientInternal?,
        andScope scope: Scope?,
        activeCrashReporterState: SentryCrashReporterState,
        scopeContextEnricher: SentryScopeContextEnricher,
        andDispatchQueue dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.init(
            testClient: client,
            andScope: scope,
            activeCrashReporterState: activeCrashReporterState,
            scopeContextEnricher: scopeContextEnricher,
            andDispatchQueue: dispatchQueue
        )
    }

    @_spi(Private) public var session: SentrySession? {
        get {
            guard let object = test_session() else { return nil }
            guard let session = object as? SentrySession else {
                XCTFail("Expected SentrySession, got \(type(of: object))")
                return nil
            }
            return session
        }
        set { test_setSession(newValue) }
    }
}

extension SentrySDKInternal {
    @_spi(Private) @nonobjc public static func setStart(with options: Options?) {
        test_setStart(with: options)
    }

    #if SWIFT_PACKAGE
    @_spi(Private) @nonobjc public static func capture(_ envelope: SentryEnvelope) {
        test_captureEnvelope(envelope)
    }

    @_spi(Private) @nonobjc public static func store(_ envelope: SentryEnvelope) {
        test_storeEnvelope(envelope)
    }
    #endif

    public static var options: Options? {
        guard let object = test_options() else { return nil }
        return requireTestBridgeValue(object)
    }
}

#if SWIFT_PACKAGE
extension Scope {
    @_spi(Private) public var propagationContext: SentryPropagationContext {
        get { requireTestBridgeValue(test_propagationContext()) }
        set { test_setPropagationContext(newValue) }
    }
}
#endif

extension TraceContext {
    @nonobjc public convenience init?(scope: Scope, options: Options) {
        self.init(testScope: scope, testOptions: options)
    }

    @_spi(Private) @nonobjc public convenience init?(tracer: SentryTracer, scope: Scope?, options: Options) {
        self.init(testTracer: tracer, scope: scope, testOptions: options)
    }

    @nonobjc public convenience init(trace: SentryId, options: Options, replayId: String?) {
        self.init(testTrace: trace, testOptions: options, replayId: replayId)
    }
}

extension TransactionContext {
    #if SWIFT_PACKAGE
    @_spi(Private) public var nameSource: SentryTransactionNameSource {
        guard let source = SentryTransactionNameSource(rawValue: test_nameSource()) else {
            preconditionFailure("Test bridge returned an invalid transaction name source")
        }
        return source
    }
    #endif

    // Keep each SDK initializer distinct: tests must exercise its real defaulting behavior.
    @_spi(Private) @nonobjc public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String
    ) {
        self.init(testName: name, rawNameSource: nameSource.rawValue, operation: operation, origin: origin)
    }

    @_spi(Private) @nonobjc public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        sampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        sampleRand: NSNumber?
    ) {
        self.init(testName: name, rawNameSource: nameSource.rawValue, operation: operation, origin: origin, sampled: sampled, sampleRate: sampleRate, sampleRand: sampleRand)
    }

    @_spi(Private) @nonobjc public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        trace: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        parentSampled: SentrySampleDecision,
        parentSampleRate: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.init(testName: name, rawNameSource: nameSource.rawValue, operation: operation, origin: origin, trace: trace, spanId: spanId, parentSpanId: parentSpanId, parentSampled: parentSampled, parentSampleRate: parentSampleRate, parentSampleRand: parentSampleRand)
    }

    @_spi(Private) @nonobjc public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        trace: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        sampled: SentrySampleDecision,
        parentSampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        parentSampleRate: NSNumber?,
        sampleRand: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.init(testName: name, rawNameSource: nameSource.rawValue, operation: operation, origin: origin, trace: trace, spanId: spanId, parentSpanId: parentSpanId, sampled: sampled, parentSampled: parentSampled, sampleRate: sampleRate, parentSampleRate: parentSampleRate, sampleRand: sampleRand, parentSampleRand: parentSampleRand)
    }
}

#if SWIFT_PACKAGE
extension SentryTracer {
    @_spi(Private) public var measurements: [String: SentryMeasurementValue] {
        requireTestBridgeValue(test_measurements())
    }
}
#endif

#if SWIFT_PACKAGE && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
extension SentrySpanInternal {
    @_spi(Private) @nonobjc public convenience init(context: SpanContext, framesTracker: SentryFramesTracker?) {
        self.init(testContext: context, testFramesTracker: framesTracker)
    }
}
#endif
