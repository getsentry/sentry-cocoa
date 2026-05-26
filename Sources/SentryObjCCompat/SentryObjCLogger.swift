// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCLogger) public final class SentryObjCLogger: NSObject {
    internal let wrapped: SentryLogger

    internal init(_ wrapped: SentryLogger) {
        self.wrapped = wrapped
    }

    @objc public func trace(_ body: String) {
        wrapped.trace(body)
    }

    @objc public func trace(_ body: String, attributes: [String: Any]) {
        wrapped.trace(body, attributes: attributes)
    }

    @objc public func debug(_ body: String) {
        wrapped.debug(body)
    }

    @objc public func debug(_ body: String, attributes: [String: Any]) {
        wrapped.debug(body, attributes: attributes)
    }

    @objc public func info(_ body: String) {
        wrapped.info(body)
    }

    @objc public func info(_ body: String, attributes: [String: Any]) {
        wrapped.info(body, attributes: attributes)
    }

    @objc public func warn(_ body: String) {
        wrapped.warn(body)
    }

    @objc public func warn(_ body: String, attributes: [String: Any]) {
        wrapped.warn(body, attributes: attributes)
    }

    @objc public func error(_ body: String) {
        wrapped.error(body)
    }

    @objc public func error(_ body: String, attributes: [String: Any]) {
        wrapped.error(body, attributes: attributes)
    }

    @objc public func fatal(_ body: String) {
        wrapped.fatal(body)
    }

    @objc public func fatal(_ body: String, attributes: [String: Any]) {
        wrapped.fatal(body, attributes: attributes)
    }
}

// swiftlint:enable missing_docs
