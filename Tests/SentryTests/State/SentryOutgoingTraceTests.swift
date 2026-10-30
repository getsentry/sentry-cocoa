@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

final class SentryOutgoingTraceTests: XCTestCase {

    private let options: Options = {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryOutgoingTraceTests")
        options.releaseName = "app@1.0.0"
        options.environment = "test"
        return options
    }()

    func testCurrent_whenNoSpan_shouldUsePropagationContext() throws {
        // -- Arrange --
        let scope = Scope()
        let expectedHeader = scope.propagationContextTraceHeader

        // -- Act --
        let trace = SentryOutgoingTrace.current(scope: scope, options: options)

        // -- Assert --
        XCTAssertFalse(trace.isFromSpan)
        XCTAssertEqual(trace.traceHeader.value(), expectedHeader.value())
        let baggage = try XCTUnwrap(trace.baggage)
        XCTAssertEqual(baggage.traceId, scope.propagationContextTraceId)
        XCTAssertEqual(baggage.releaseName, "app@1.0.0")
        XCTAssertEqual(baggage.environment, "test")
    }

    func testCurrent_whenTracerBoundToScope_shouldUseSpan() throws {
        // -- Arrange --
        let scope = Scope()
        let hub = SentryHubInternal(client: SentryClientInternal(options: options), andScope: scope)
        let tracer = SentryTracer(
            transactionContext: TransactionContext(name: "transaction", operation: "ui.load", sampled: .yes, sampleRate: nil, sampleRand: nil),
            hub: hub
        )
        scope.span = tracer

        // -- Act --
        let trace = SentryOutgoingTrace.current(scope: scope, options: options)

        // -- Assert --
        XCTAssertTrue(trace.isFromSpan)
        XCTAssertEqual(trace.traceHeader.value(), tracer.toTraceHeader().value())
        let baggage = try XCTUnwrap(trace.baggage)
        XCTAssertEqual(baggage.traceId, tracer.traceId)
        XCTAssertEqual(baggage.sampled, "true")
    }

    func testCurrent_whenChildSpanBoundToScope_shouldUseChildHeaderAndTracerBaggage() throws {
        // -- Arrange --
        let scope = Scope()
        let hub = SentryHubInternal(client: SentryClientInternal(options: options), andScope: scope)
        let tracer = SentryTracer(
            transactionContext: TransactionContext(name: "transaction", operation: "ui.load", sampled: .yes, sampleRate: nil, sampleRand: nil),
            hub: hub
        )
        let child = tracer.startChild(operation: "child")
        scope.span = child

        // -- Act --
        let trace = SentryOutgoingTrace.current(scope: scope, options: options)

        // -- Assert --
        XCTAssertTrue(trace.isFromSpan)
        XCTAssertEqual(trace.traceHeader.value(), child.toTraceHeader().value())
        XCTAssertEqual(trace.baggage?.traceId, tracer.traceId)
    }
}
