@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryPerformanceTracker: NSObject {
    private let helper = SentryPerformanceTrackerHelper.shared
    
    // Only visible for testing
    @objc private var activeSpanStack: NSMutableArray {
        helper.activeSpanStack
    }

    /// A static instance of performance tracker.
    @objc public static let shared = SentryPerformanceTracker()
    
    /// Starts a new span if no span is active, then bind it to the scope if no span is bound.
    /// @note If there's an active span, starts a child of the active span.
    /// @param name Span name.
    /// @param source the transaction name source.
    /// @param operation Span operation.
    /// @return The span id.
    @objc public func startSpan(withName name: String, nameSource source: SentryTransactionNameSource, operation: String, origin: String) -> SpanId {
        helper.startSpan(withName: name, nameSource: source.rawValue, operation: operation, origin: origin)
    }

    /// Activate the span with @c spanId to create any call to @c startSpan as a child.
    /// @note If the there is no span with @c spanId , @c block is executed anyway.
    /// @param spanId Id of the span to activate
    /// @param block Block to invoke while span is active
    @objc public func activateSpan(_ spanId: SpanId, duringBlock block: @escaping () -> Void) {
        helper.activateSpan(spanId, duringBlock: block)
    }

    /// Measure the given @c block execution.
    /// @param description The description of the span.
    /// @param source the transaction name source.
    /// @param operation Span operation.
    /// @param block Block to be measured.
    @objc public func measureSpan(withDescription description: String, nameSource source: SentryTransactionNameSource, operation: String, origin: String, inBlock block: @escaping () -> Void) {
        helper.measureSpan(withDescription: description, nameSource: source.rawValue, operation: operation, origin: origin, in: block)
    }

    /// Measure the given @c block execution adding it as a child of given parent span.
    /// @note If @c parentSpanId does not exist this measurement is not performed.
    /// @param description The description of the span.
    /// @param source the transaction name source.
    /// @param operation Span operation.
    /// @param parentSpanId Id of the span to use as parent.
    /// @param block Block to be measured.
    @objc public func measureSpan(withDescription description: String, nameSource source: SentryTransactionNameSource, operation: String, origin: String, parentSpanId: SpanId, inBlock block: @escaping () -> Void) {
        helper.measureSpan(withDescription: description, nameSource: source.rawValue, operation: operation, origin: origin, parentSpanId: parentSpanId, in: block)
    }

    /// Gets the active span id.
    @objc public func activeSpanId() -> SpanId? {
        helper.activeSpanId()
    }

    /// Marks a span to be finished.
    /// If the given span has no child it is finished immediately, otherwise it waits until all children
    /// are finished.
    /// @param spanId Id of the span to finish.
    @objc public func finishSpan(_ spanId: SpanId) {
        helper.finishSpan(spanId)
    }

    /// Marks a span to be finished with given status.
    /// If the given span has no child it is finished immediately, otherwise it waits until all children
    /// are finished.
    /// @param spanId Id of the span to finish.
    /// @param status Span finish status.
    @objc(finishSpan:withStatus:) public func finishSpan(_ spanId: SpanId, with status: SentrySpanStatus) {
        helper.finishSpan(spanId, with: status)
    }

    /// Checks if given span is waiting to be finished.
    /// @param spanId Id of the span to be checked.
    /// @return A boolean value indicating whether the span still waiting to be finished.
    @objc public func isSpanAlive(_ spanId: SpanId) -> Bool {
        helper.isSpanAlive(spanId)
    }

    /// Return the SentrySpan associated with the given spanId.
    /// @param spanId Id of the span to return.
    /// @return SentrySpan
    func getSpan(_ spanId: SpanId) -> (any Span)? {
        helper.getSpan(spanId)
    }
    
    // Whe making this function visible to ObjC it cannot use the Span protocol
    // because that creates compiler errors when building with Cocoapods.
    @objc public func getSpanForObjc(_ spanId: SpanId) -> Any? {
        getSpan(spanId)
    }

    public func hasSpan(_ spanId: SpanId) -> Bool {
        getSpan(spanId) != nil
    }

    @discardableResult @objc public func pushActiveSpan(_ spanId: SpanId) -> Bool {
        helper.pushActiveSpan(spanId)
    }

    @objc public func popActiveSpan() {
        helper.popActiveSpan()
    }
    
    func clear() {
        helper.clear()
    }
}
