@_implementationOnly import Sentry
import Foundation

/// Severity of a Sentry event or breadcrumb.
///
/// Raw values match `Sentry.SentryLevel` so an unchecked bitcast is safe.
@objc(SentryCompatLevel)
public enum SentryLevel: UInt {
    case none = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case fatal = 5
}

extension SentryLevel {
    init(_ underlying: Sentry.SentryLevel) {
        self = SentryLevel(rawValue: underlying.rawValue) ?? .none
    }

    var underlying: Sentry.SentryLevel {
        Sentry.SentryLevel(rawValue: rawValue) ?? .none
    }
}
