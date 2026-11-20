internal import _SentryPrivate
import Foundation

/// Trace state propagated with an event or envelope, and to downstream services as baggage.
@objc(SentryTraceContext)
open class TraceContext: NSObject {
    /// UUID V4 encoded as a hexadecimal sequence with no dashes (e.g. 771a43a4192642f0b136d5159a501700)
    /// that is a sequence of 32 hexadecimal digits.
    @objc open private(set) var traceId: SentryId

    /// Public key from the DSN used by the SDK.
    @objc open private(set) var publicKey: String

    /// The release name as specified in client options, usually: package@x.y.z+build.
    @objc open private(set) var releaseName: String?

    /// The environment name as specified in client options, for example staging.
    @objc open private(set) var environment: String?

    /// The transaction name set on the scope.
    @objc open private(set) var transaction: String?

    /// Serialized sample rate used for this trace.
    @objc open private(set) var sampleRate: String?

    /// Serialized random value used to determine if the trace is sampled.
    @objc open private(set) var sampleRand: String?

    /// Value indicating whether the trace was sampled.
    @objc open private(set) var sampled: String?

    /// Id of the current session replay.
    @objc open private(set) var replayId: String?

    /// The organization ID extracted from the DSN or configured explicitly.
    @objc open private(set) var orgId: String?

    /// Creates an empty trace context.
    ///
    /// Callers that have a trace id and public key should use an initializer that takes them.
    public required override convenience init() {
        self.init(
            trace: SentryId.empty,
            publicKey: "",
            releaseName: nil,
            environment: nil,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: nil,
            orgId: nil
        )
    }

    init(
        trace traceId: SentryId,
        publicKey: String,
        releaseName: String?,
        environment: String?,
        transaction: String?,
        sampleRate: String?,
        sampleRand: String?,
        sampled: String?,
        replayId: String?,
        orgId: String?
    ) {
        self.traceId = traceId
        self.publicKey = publicKey
        self.releaseName = releaseName
        self.environment = environment
        self.transaction = transaction
        self.sampleRate = sampleRate
        self.sampleRand = sampleRand
        self.sampled = sampled
        self.replayId = replayId
        self.orgId = orgId
        super.init()
    }

    convenience init(
        trace traceId: SentryId,
        publicKey: String,
        releaseName: String?,
        environment: String?,
        transaction: String?,
        sampleRate: String?,
        sampled: String?,
        replayId: String?
    ) {
        self.init(
            trace: traceId,
            publicKey: publicKey,
            releaseName: releaseName,
            environment: environment,
            transaction: transaction,
            sampleRate: sampleRate,
            sampleRand: nil,
            sampled: sampled,
            replayId: replayId,
            orgId: nil
        )
    }

    convenience init(
        trace traceId: SentryId,
        publicKey: String,
        releaseName: String?,
        environment: String?,
        transaction: String?,
        sampleRate: String?,
        sampleRand: String?,
        sampled: String?,
        replayId: String?
    ) {
        self.init(
            trace: traceId,
            publicKey: publicKey,
            releaseName: releaseName,
            environment: environment,
            transaction: transaction,
            sampleRate: sampleRate,
            sampleRand: sampleRand,
            sampled: sampled,
            replayId: replayId,
            orgId: nil
        )
    }

    convenience init?(scope: Scope, options: Options) {
        guard let tracer = SentryTracer.getTracer(scope.span) else {
            return nil
        }
        self.init(tracer: tracer, scope: scope, options: options)
    }

    convenience init?(tracer: SentryTracer, scope: Scope?, options: Options) {
        // `traceId` is nonnull in the header, but Objective-C callers can still store nil.
        guard let traceId = tracer.value(forKey: "traceId") as? SentryId,
              let publicKey = options.parsedDsn?.url.user else {
            return nil
        }

        let serializedSampleRand = tracer.transactionContext.sampleRand.map {
            String(format: "%f", $0.doubleValue)
        }
        let serializedSampleRate = tracer.transactionContext.sampleRate.map {
            String(format: "%f", $0.doubleValue)
        }
        let sampled: String?
        if tracer.sampled == .undecided {
            sampled = nil
        } else {
            sampled = tracer.sampled == .yes ? "true" : "false"
        }

        self.init(
            trace: traceId,
            publicKey: publicKey,
            releaseName: options.releaseName,
            environment: options.environment,
            transaction: tracer.transactionContext.name,
            sampleRate: serializedSampleRate,
            sampleRand: serializedSampleRand,
            sampled: sampled,
            replayId: scope?.replayId,
            orgId: options.effectiveOrgId
        )
    }

    /// Creates a trace context from an SDK-internal tracer.
    ///
    /// Objective-C passes the tracer as an untyped object because `SentryTracer` cannot appear in
    /// an `@objc` signature. Returns nil when that object is not a tracer, or when the tracer has
    /// no trace id or the options have no parsed DSN.
    @_spi(Private)
    @objc(initWithTracer:scope:options:)
    public convenience init?(tracerObject: AnyObject, scope: Scope?, options: Options) {
        guard let tracer = tracerObject as? SentryTracer else {
            return nil
        }
        self.init(tracer: tracer, scope: scope, options: options)
    }

    /// Creates a trace context from a trace id, the SDK options, and an optional replay id.
    @_spi(Private)
    @objc(initWithTraceId:options:replayId:)
    public convenience init(trace traceId: SentryId, options: Options, replayId: String?) {
        self.init(
            trace: traceId,
            publicKey: options.parsedDsn?.url.user ?? "",
            releaseName: options.releaseName,
            environment: options.environment,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: replayId,
            orgId: options.effectiveOrgId
        )
    }

    /// Creates a trace context from a serialized dictionary.
    ///
    /// Returns nil when `trace_id` is missing or not a string, or when `public_key` is missing.
    @_spi(Private)
    public convenience init?(dict dictionary: [String: Any]) {
        let rawTraceId = dictionary["trace_id"]
        guard let traceIdString = rawTraceId as? String else {
            SentrySDKLog.error("Invalid trace_id: \(String(describing: rawTraceId))")
            return nil
        }
        guard let publicKey = dictionary["public_key"] as? String else {
            return nil
        }

        self.init(
            trace: SentryId(uuidString: traceIdString),
            publicKey: publicKey,
            releaseName: dictionary["release"] as? String,
            environment: dictionary["environment"] as? String,
            transaction: dictionary["transaction"] as? String,
            sampleRate: dictionary["sample_rate"] as? String,
            sampleRand: dictionary["sample_rand"] as? String,
            sampled: dictionary["sampled"] as? String,
            replayId: dictionary["replay_id"] as? String,
            orgId: dictionary["org_id"] as? String
        )
    }

    /// Creates a baggage value from this trace context.
    @objc
    @discardableResult
    open func toBaggage() -> Baggage {
        Baggage(
            trace: traceId,
            publicKey: publicKey,
            releaseName: releaseName,
            environment: environment,
            transaction: transaction,
            sampleRate: sampleRate,
            sampleRand: sampleRand,
            sampled: sampled,
            replayId: replayId,
            orgId: orgId
        )
    }

    #if !SDK_V10
    /// Serializes the trace context to a dictionary.
    @objc
    @discardableResult
    open func serialize() -> [String: Any] {
        serializedTraceContext()
    }
    #else
    @objc
    func serialize() -> [String: Any] {
        serializedTraceContext()
    }
    #endif

    private func serializedTraceContext() -> [String: Any] {
        var result: [String: Any] = [
            "trace_id": traceId.sentryIdString,
            "public_key": publicKey
        ]
        if let releaseName {
            result["release"] = releaseName
        }
        if let environment {
            result["environment"] = environment
        }
        if let transaction {
            result["transaction"] = transaction
        }
        if let sampleRand {
            result["sample_rand"] = sampleRand
        }
        if let sampleRate {
            result["sample_rate"] = sampleRate
        }
        if let sampled {
            result["sampled"] = sampled
        }
        if let replayId {
            result["replay_id"] = replayId
        }
        if let orgId {
            result["org_id"] = orgId
        }
        return result
    }
}

#if !SDK_V10
extension TraceContext: SentrySerializable {}
#endif

// A public class cannot conform to SentryInternalSerializable: that protocol is imported
// internally from _SentryPrivate, and Swift publishes every conformance of a public type.
// serialize() stays @objc so Objective-C and Swift callers still invoke it directly.
