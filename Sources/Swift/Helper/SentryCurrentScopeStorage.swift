import Foundation

/// Thread-local storage for the current scope used by `withCurrentScope`.
@objc(SentryCurrentScopeStorage)
@objcMembers
@_spi(Private) public final class SentryCurrentScopeStorage: NSObject {

    private static let key = "io.sentry.currentScope"

    /// Returns the current scope for this thread, or `nil` if none is set.
    @_spi(Private) public func scope() -> Scope? {
        Thread.current.threadDictionary[Self.key] as? Scope
    }

    /// Sets the given scope as the current scope for the duration of the callback.
    @_spi(Private) public func withScope(_ scope: Scope, callback: () -> Void) {
        let threadDict = Thread.current.threadDictionary
        let previous = threadDict[Self.key]
        threadDict[Self.key] = scope
        callback()
        if let previous {
            threadDict[Self.key] = previous
        } else {
            threadDict.removeObject(forKey: Self.key)
        }
    }

    @_spi(Private) public override init() {
        super.init()
    }
}
