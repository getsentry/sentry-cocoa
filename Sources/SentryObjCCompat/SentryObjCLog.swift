// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCLog: NSObject {
    internal let wrapped: SentryLog

    internal init(_ wrapped: SentryLog) {
        self.wrapped = wrapped
    }

    @objc public init(level: SentryObjCLogLevel, body: String) {
        self.wrapped = SentryLog(level: level.underlying, body: body)
    }

    @objc public init(level: SentryObjCLogLevel, body: String, attributes: [String: SentryObjCAttribute]) {
        self.wrapped = SentryLog(
            level: level.underlying,
            body: body,
            attributes: attributes.mapValues { $0.wrapped }
        )
    }

    @objc public var timestamp: Date {
        get { wrapped.timestamp }
        set { wrapped.timestamp = newValue }
    }

    @objc public var traceId: SentryObjCId {
        get { SentryObjCId(wrapped.traceId) }
        set { wrapped.traceId = newValue.wrapped }
    }

    @objc public var spanId: SentryObjCSpanId? {
        get { wrapped.spanId.map { SentryObjCSpanId($0) } }
        set { wrapped.spanId = newValue?.wrapped }
    }

    @objc public var level: SentryObjCLogLevel {
        get { SentryObjCLogLevel(wrapped.level) }
        set { wrapped.level = newValue.underlying }
    }

    @objc public var body: String {
        get { wrapped.body }
        set { wrapped.body = newValue }
    }

    @objc public var attributes: [String: SentryObjCAttribute] {
        get { wrapped.attributes.mapValues { SentryObjCAttribute($0) } }
        set { wrapped.attributes = newValue.mapValues { $0.wrapped } }
    }

    @objc public var severityNumber: NSNumber? {
        get { wrapped.severityNumber }
        set { wrapped.severityNumber = newValue }
    }

    @objc public func setAttribute(_ attribute: SentryObjCAttribute?, forKey key: String) {
        wrapped.setAttribute(attribute?.wrapped, forKey: key)
    }
}

// swiftlint:enable missing_docs
