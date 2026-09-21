#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryTestsObjCHelpers

// Clang cannot resolve Swift-owned types in a separate module. These adapters keep the
// assertions typed while calling the original SDK selectors through test-only declarations.
func packageTestCast<T>(_ value: Any, to type: T.Type = T.self) -> T {
    guard let result = value as? T else {
        preconditionFailure("Invalid test bridge: expected \(type), got \(Swift.type(of: value))")
    }
    return result
}

extension SentryClientInternal {
    var fileManager: SentryFileManager {
        get { packageTestCast(SentryTestClientFileManager(self)) }
        set { SentryTestSetClientFileManager(self, newValue) }
    }
    var options: Options { packageTestCast(SentryTestClientOptions(self)) }
}

extension SentryHubInternal {
    var session: SentrySession? {
        get { SentryTestHubSession(self).map { packageTestCast($0) } }
        set { SentryTestSetHubSession(self, newValue) }
    }
}

extension SentrySDKInternal {
    static var options: Options? { SentryTestSDKOptions().map { packageTestCast($0) } }
}

extension Scope {
    var propagationContext: SentryPropagationContext {
        get { packageTestCast(SentryTestScopePropagationContext(self)) }
        set { SentryTestSetScopePropagationContext(self, newValue) }
    }
}

extension SentryTracer {
    var measurements: [String: SentryMeasurementValue] { packageTestCast(SentryTestTracerMeasurements(self)) }
}

extension TransactionContext {
    var nameSource: SentryTransactionNameSource {
        guard let source = SentryTransactionNameSource(rawValue: SentryTestTransactionNameSource(self)) else {
            preconditionFailure("Invalid transaction name source in test bridge")
        }
        return source
    }

    convenience init(name: String, nameSource: SentryTransactionNameSource, operation: String, origin: String) {
        self.init(name: name, testNameSource: nameSource.rawValue, operation: operation, origin: origin)
    }

    convenience init(name: String, nameSource: SentryTransactionNameSource, operation: String, origin: String,
                     sampled: SentrySampleDecision, sampleRate: NSNumber?, sampleRand: NSNumber?) {
        self.init(name: name, testNameSource: nameSource.rawValue, operation: operation, origin: origin,
                  sampled: sampled, sampleRate: sampleRate, sampleRand: sampleRand)
    }

    convenience init(name: String, nameSource: SentryTransactionNameSource, operation: String, origin: String,
                     trace traceId: SentryId, spanId: SpanId, parentSpanId: SpanId?, parentSampled: SentrySampleDecision,
                     parentSampleRate: NSNumber?, parentSampleRand: NSNumber?) {
        self.init(name: name, testNameSource: nameSource.rawValue, operation: operation, origin: origin,
                  traceId: traceId, spanId: spanId, parentSpanId: parentSpanId, parentSampled: parentSampled,
                  parentSampleRate: parentSampleRate, parentSampleRand: parentSampleRand)
    }

    convenience init(name: String, nameSource: SentryTransactionNameSource, operation: String, origin: String,
                     trace traceId: SentryId, spanId: SpanId, parentSpanId: SpanId?, sampled: SentrySampleDecision,
                     parentSampled: SentrySampleDecision, sampleRate: NSNumber?, parentSampleRate: NSNumber?,
                     sampleRand: NSNumber?, parentSampleRand: NSNumber?) {
        self.init(name: name, testNameSource: nameSource.rawValue, operation: operation, origin: origin,
                  traceId: traceId, spanId: spanId, parentSpanId: parentSpanId, sampled: sampled,
                  parentSampled: parentSampled, sampleRate: sampleRate, parentSampleRate: parentSampleRate,
                  sampleRand: sampleRand, parentSampleRand: parentSampleRand)
    }
}

#if !SDK_V10
extension SentryCrashScopeHelper {
    static func getScopeObserver(withMaxBreacdrumb maxBreadcrumbs: Int) -> SentryScopeObserver {
        // Match SentryCrashScopeHelper.m's id<SentryScopeObserver> cast. The legacy observer
        // implements the tested selectors without formally declaring protocol conformance.
        unsafeBitCast(SentryTestCrashScopeObserver(maxBreadcrumbs), to: SentryScopeObserver.self)
    }
}
#endif

extension TransportInitializer {
    static func initTransports(_ options: Options, dateProvider: SentryCurrentDateProvider,
                               sentryFileManager: SentryFileManager, rateLimits: RateLimits,
                               reachability: SentryReachability) -> [Transport] {
        packageTestCast(SentryTestInitTransports(options, dateProvider, sentryFileManager, rateLimits, reachability))
    }
}

// Preserve the test fixture's constructor spelling without redeclaring the SDK's ObjC class.
// swiftlint:disable:next identifier_name
func SentryHttpTransport(dsn: SentryDsn, sendClientReports: Bool, cachedEnvelopeSendDelay: TimeInterval,
                         dateProvider: SentryCurrentDateProvider, fileManager: SentryFileManager,
                         requestManager: RequestManager, requestBuilder: SentryNSURLRequestBuilder,
                         rateLimits: RateLimits, envelopeRateLimit: EnvelopeRateLimit,
                         dispatchQueueWrapper: SentryDispatchQueueWrapper, reachability: SentryReachability) -> Transport {
    packageTestCast(SentryTestMakeHttpTransport(dsn, sendClientReports, cachedEnvelopeSendDelay,
        dateProvider, fileManager, requestManager, requestBuilder, rateLimits, envelopeRateLimit,
        dispatchQueueWrapper, reachability))
}

extension EnvelopeRateLimit {
    func removeRateLimitedItems(_ envelope: SentryEnvelope) -> SentryEnvelope {
        packageTestCast(SentryTestRemoveRateLimitedItems(self, envelope))
    }
}
#endif
