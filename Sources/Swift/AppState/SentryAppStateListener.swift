@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) @objc public protocol SentryAppStateListener: NSObjectProtocol {
    @objc optional func appStateManagerWillResignActive()
    @objc optional func appStateManagerWillTerminate()
}
