// swiftlint:disable missing_docs
import Foundation

#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

// See SentryReplayOptionsCompat.swift for the rationale on why this
// wrapper exists (mangled ObjC runtime names).
//
// TYPE-ERASING LIMITATION
// -----------------------
// This file uses full type-erasing: SDK types (SentryId, SentryLog.Level,
// SentryAttribute) are replaced with NSObject / Int / [String: NSObject]
// in every public signature.  This is a known consequence of
// internal import: types from an impl-only imported module
// CANNOT appear in a public or @usableFromInline interface.
//
// What this costs:
//   - ObjC consumers lose compile-time type safety on these parameters.
//     traceId accepts any NSObject (must be SentryId at runtime), level
//     accepts any Int (must be a valid SentryLog.Level raw value), and
//     attributes accepts [String: NSObject] (must be SentryAttribute
//     instances at runtime).
//   - Invalid types are silently ignored (e.g., a non-SentryId traceId
//     assignment is dropped, non-SentryAttribute values are filtered out
//     by compactMapValues).
//
// Why it's necessary:
//   Without internal import, the SentryObjCCompat module would
//   re-export Sentry's Swift types in its .swiftmodule, which defeats
//   the entire purpose of the pure-ObjC wrapper (no *-Swift.h in the
//   consumer's build graph).
//
// The alternative — adding @objc(SentryLog) to the original Swift class
// — eliminates this wrapper entirely and restores full type safety, but
// modifies existing SDK source files.
@objc(SentryLog)
public class SentryLogCompat: NSObject {
    let inner: SentryLog

    @objc public var timestamp: Date {
        get { inner.timestamp }
        set { inner.timestamp = newValue }
    }
    @objc public var traceId: NSObject {
        get { inner.traceId }
        set { if let id = newValue as? SentryId { inner.traceId = id } }
    }
    @objc public var body: String {
        get { inner.body }
        set { inner.body = newValue }
    }
    @objc public var severityNumber: NSNumber? {
        get { inner.severityNumber }
        set { inner.severityNumber = newValue }
    }

    @objc public init(level: Int, body: String) {
        let logLevel = SentryLog.Level(rawValue: level) ?? .info
        self.inner = SentryLog(level: logLevel, body: body)
        super.init()
    }

    @objc public init(level: Int, body: String, attributes: [String: NSObject]) {
        let logLevel = SentryLog.Level(rawValue: level) ?? .info
        let swiftAttrs = attributes.compactMapValues { $0 as? SentryAttribute }
        self.inner = SentryLog(level: logLevel, body: body, attributes: swiftAttrs)
        super.init()
    }

    @objc public func setAttribute(_ attribute: NSObject?, forKey key: String) {
        inner.setAttribute(attribute as? SentryAttribute, forKey: key)
    }
}
