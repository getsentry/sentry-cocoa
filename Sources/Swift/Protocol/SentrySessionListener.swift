@_implementationOnly import _SentryPrivate
import Foundation

@objc
public protocol SentrySessionListener: NSObjectProtocol {
    func sentrySessionEnded()
    func sentrySessionStarted()
}
