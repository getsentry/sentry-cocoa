@_implementationOnly import Sentry
import Foundation

/// Parsed representation of a Sentry DSN.
@objc(SOCSentryDsn)
public final class Dsn: NSObject {
    internal let wrapped: Sentry.SentryDsn

    internal init(_ wrapped: Sentry.SentryDsn) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init?(string dsnString: String?, didFailWithError error: NSErrorPointer) {
        guard let parsed = Sentry.SentryDsn(string: dsnString, didFailWithError: error) else {
            return nil
        }
        self.wrapped = parsed
        super.init()
    }

    @objc public var url: URL { wrapped.url }

    @objc public func getEnvelopeEndpoint() -> URL { wrapped.getEnvelopeEndpoint() }
}
