#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

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
