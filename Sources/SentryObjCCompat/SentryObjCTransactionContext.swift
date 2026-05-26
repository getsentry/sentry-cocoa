// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCTransactionContext) public final class SentryObjCTransactionContext: SentryObjCSpanContext {
    internal var wrappedTransaction: TransactionContext {
        // swiftlint:disable:next force_cast
        wrapped as! TransactionContext
    }

    internal init(_ wrapped: TransactionContext) {
        super.init(wrapped)
    }

    @objc public init(name: String, operation: String) {
        super.init(TransactionContext(name: name, operation: operation))
    }

    @objc public init(name: String, operation: String, sampled: SentryObjCSampleDecision, sampleRate: NSNumber?, sampleRand: NSNumber?) {
        super.init(TransactionContext(name: name, operation: operation, sampled: sampled.underlying, sampleRate: sampleRate, sampleRand: sampleRand))
    }

    @objc public init(name: String, operation: String, traceId: SentryObjCId, spanId: SentryObjCSpanId, parentSpanId: SentryObjCSpanId?, parentSampled: SentryObjCSampleDecision, parentSampleRate: NSNumber?, parentSampleRand: NSNumber?) {
        super.init(TransactionContext(name: name, operation: operation, trace: traceId.wrapped, spanId: spanId.wrapped, parentSpanId: parentSpanId?.wrapped, parentSampled: parentSampled.underlying, parentSampleRate: parentSampleRate, parentSampleRand: parentSampleRand))
    }

    @objc public var name: String {
        wrappedTransaction.name
    }

    @objc public var nameSource: SentryObjCTransactionNameSource {
        // SentryTransactionNameSource is forward-declared in ObjC headers but defined in Swift,
        // so the property is unavailable through the ObjC import. Use KVC to read the raw value.
        guard let raw = wrappedTransaction.value(forKey: "nameSource") as? Int else {
            return .custom
        }
        return SentryObjCTransactionNameSource(rawValue: raw) ?? .custom
    }

    @objc public var sampleRate: NSNumber? {
        get { wrappedTransaction.sampleRate }
        set { wrappedTransaction.sampleRate = newValue }
    }

    @objc public var sampleRand: NSNumber? {
        get { wrappedTransaction.sampleRand }
        set { wrappedTransaction.sampleRand = newValue }
    }

    @objc public var parentSampled: SentryObjCSampleDecision {
        get { SentryObjCSampleDecision(wrappedTransaction.parentSampled) }
        set { wrappedTransaction.parentSampled = newValue.underlying }
    }

    @objc public var parentSampleRate: NSNumber? {
        get { wrappedTransaction.parentSampleRate }
        set { wrappedTransaction.parentSampleRate = newValue }
    }

    @objc public var parentSampleRand: NSNumber? {
        get { wrappedTransaction.parentSampleRand }
        set { wrappedTransaction.parentSampleRand = newValue }
    }

    @objc public var forNextAppLaunch: Bool {
        get { wrappedTransaction.forNextAppLaunch }
        set { wrappedTransaction.forNextAppLaunch = newValue }
    }
}

// swiftlint:enable missing_docs
