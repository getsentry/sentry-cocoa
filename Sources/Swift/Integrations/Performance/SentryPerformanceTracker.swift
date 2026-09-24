internal import _SentryPrivate
import Foundation

/// Tracks performance spans and waits for their children before finishing transactions.
@_spi(Private) @objc public final class SentryPerformanceTracker: NSObject {
    /// The shared performance tracker.
    @objc public static let shared = SentryPerformanceTracker()

    // Keep the collections as reference types: they are also the synchronization objects.
    @objc private let spans = NSMutableDictionary()
    @objc private let activeSpanStack = NSMutableArray()
    private let delegateAdapter = PerformanceTrackerDelegate()

    /// Creates an independent performance tracker.
    @objc public override init() {
        super.init()
        delegateAdapter.tracker = self
    }

    /// Starts a child of the active span, or a transaction bound to an available scope.
    @objc(startSpanWithName:nameSource:operation:origin:)
    // swiftlint:disable:next function_body_length
    public func startSpan(withName name: String, nameSource: Int, operation: String, origin: String) -> SpanId {
        var activeSpan: Span?
#if !(os(watchOS) || os(tvOS) || os(visionOS))
        activeSpan = sentry_launchTracer
#endif
        if activeSpan == nil {
            synchronized(activeSpanStack) { [self] in
                activeSpan = activeSpanStack.lastObject as? Span
            }
        }

        let newSpan: Span?
        if let activeSpan = activeSpan {
            newSpan = activeSpan.startChild(operation: operation, description: name)
            newSpan?.origin = origin
        } else {
            let context: TransactionContext
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            if let appStartTraceId = SentryAppStartMeasurementProvider.consumeAppStartTraceId() {
                context = TransactionContext(name: name, rawNameSource: nameSource, operation: operation, origin: origin, trace: appStartTraceId)
            } else {
                context = TransactionContext(name: name, rawNameSource: nameSource, operation: operation, origin: origin)
            }
#else
            context = TransactionContext(name: name, rawNameSource: nameSource, operation: operation, origin: origin)
#endif
            let span = SentrySDKInternal.currentHub().scope.span
            var bindToScope = false
            if span == nil {
                bindToScope = true
            }
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            if let span = span, SentrySpanOperationIsUIEvent(span.operation) {
                SentrySDKLog.debug("Cancelling previous UI event span \(span.spanId.sentrySpanIdString)")
                span.finish(status: .cancelled)
                bindToScope = true
            }
#endif
            SentrySDKLog.debug("Starting new transaction for \(name) with bindToScope: \(bindToScope ? 1 : 0)")
            let tracer = SentrySDKInternal.currentHub().startTransaction(
                with: context,
                bindToScope: bindToScope,
                customSamplingContext: [:],
                configuration: SentryTracerConfiguration { configuration in
                    configuration.waitForChildren = true
                    configuration.finishMustBeCalled = true
                }
            )
            tracer.delegate = delegateAdapter
            newSpan = tracer
        }

        guard let spanId = newSpan?.spanId else {
            SentrySDKLog.error("startSpanWithName:operation: spanId is nil.")
            return SpanId.empty
        }
        synchronized(spans) { [self] in
            spans[spanId] = newSpan
        }
        return spanId
    }

    /// Measures a block with a span, making that span active for the duration of the block.
    @objc(measureSpanWithDescription:nameSource:operation:origin:inBlock:)
    public func measureSpan(withDescription description: String, nameSource: Int, operation: String, origin: String, in block: () -> Void) {
        let spanId = startSpan(withName: description, nameSource: nameSource, operation: operation, origin: origin)
        SentrySDKLog.debug("Measuring span \(spanId.sentrySpanIdString); description \(description); operation: \(operation)")
        pushActiveSpan(spanId)
        block()
        popActiveSpan()
        finishSpan(spanId)
    }

    /// Measures a block with a child span of the given parent, if the parent is tracked.
    @objc(measureSpanWithDescription:nameSource:operation:origin:parentSpanId:inBlock:)
    public func measureSpan(withDescription description: String, nameSource: Int, operation: String, origin: String, parentSpanId: SpanId, in block: () -> Void) {
        activateSpan(parentSpanId) { [self] in
            measureSpan(withDescription: description, nameSource: nameSource, operation: operation, origin: origin, in: block)
        }
    }

    /// Activates a tracked span while executing the block. Unknown IDs still execute the block.
    @objc(activateSpan:duringBlock:)
    public func activateSpan(_ spanId: SpanId, during block: () -> Void) {
        if pushActiveSpan(spanId) {
            block()
            popActiveSpan()
        } else {
            block()
        }
    }

    /// Returns the ID of the active span.
    @objc public func activeSpanId() -> SpanId? {
        synchronized(activeSpanStack) { [self] in
            (activeSpanStack.lastObject as? Span)?.spanId
        }
    }

    /// Pushes a tracked span onto the active stack, returning whether it was found.
    @discardableResult
    @objc public func pushActiveSpan(_ spanId: SpanId) -> Bool {
        SentrySDKLog.debug("Pushing active span \(spanId.sentrySpanIdString)")
        let span = synchronized(spans) { [self] in
            spans[spanId] as? Span
        }

        guard let span = span else {
            SentrySDKLog.debug("No span found with ID \(spanId.sentrySpanIdString)")
            return false
        }
        synchronized(activeSpanStack) { [self] in
            activeSpanStack.add(span)
        }
        return true
    }

    /// Removes the most recently activated span.
    @objc public func popActiveSpan() {
        synchronized(activeSpanStack) { [self] in
            activeSpanStack.removeLastObject()
        }
    }

    /// Finishes a span successfully, waiting for children if it is a transaction.
    @objc public func finishSpan(_ spanId: SpanId) {
        SentrySDKLog.debug("Finishing performance span \(spanId.sentrySpanIdString)")
        finishSpan(spanId, with: .ok)
    }

    /// Finishes a span with the given status, waiting for children if it is a transaction.
    @objc(finishSpan:withStatus:)
    public func finishSpan(_ spanId: SpanId, with status: SentrySpanStatus) {
        let span = synchronized(spans) { [self] in
            let span = spans[spanId] as? Span
            // Automatic tracers may have no other owner. Retain them until tracerDidFinish.
            if !(span is SentryTracer) {
                spans.removeObject(forKey: spanId)
            }
            return span
        }
        span?.finish(status: status)
    }

    /// Returns whether the span is still tracked.
    @objc public func isSpanAlive(_ spanId: SpanId) -> Bool {
        synchronized(spans) { [self] in
            spans[spanId] != nil
        }
    }

    /// Returns the tracked span for an ID.
    @objc public func getSpan(_ spanId: SpanId) -> Span? {
        synchronized(spans) { [self] in
            spans[spanId] as? Span
        }
    }

    /// Returns whether a span with the given ID exists.
    @objc public func hasSpan(_ spanId: SpanId) -> Bool {
        getSpan(spanId) != nil
    }

    /// Returns the most recently activated span.
    @objc public func getActiveSpan() -> Span? {
        synchronized(activeSpanStack) { [self] in
            activeSpanStack.lastObject as? Span
        }
    }

    /// Clears tracked and active spans.
    @objc public func clear() {
        activeSpanStack.removeAllObjects()
        spans.removeAllObjects()
    }

    @objc func tracerDidFinish(_ tracer: SentryTracer) {
        synchronized(spans) { [self] in
            spans.removeObject(forKey: tracer.spanId)
        }
    }
}

// Temporary local equivalent of Objective-C @synchronized for this conversion.
private func synchronized<T>(_ object: AnyObject, operation: () throws -> T) rethrows -> T {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }
    return try operation()
}

// The public Swift type cannot expose a conformance imported from _SentryPrivate.
// Keep the delegate weak, as it was when the tracer referenced the tracker directly.
private final class PerformanceTrackerDelegate: NSObject, SentryTracerDelegate {
    weak var tracker: SentryPerformanceTracker?

    func getActiveSpan() -> Span? {
        tracker?.getActiveSpan()
    }

    func tracerDidFinish(_ tracer: SentryTracer) {
        tracker?.tracerDidFinish(tracer)
    }
}
