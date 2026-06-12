import Foundation

extension SentrySDK {

    private static let internalLock = NSRecursiveLock()
    private static var _internal: SentryInternalApi?

    /// APIs for hybrid SDKs (React Native, Flutter, .NET, Unity).
    ///
    /// These APIs may change in any minor release without deprecation.
    /// App developers should use the standard `SentrySDK` API instead.
    @_spi(Private) public static var `internal`: SentryInternalApi {
        internalLock.synchronized {
            if let existing = _internal { return existing }
            let instance = SentryInternalApi()
            _internal = instance
            return instance
        }
    }

    static func resetInternalApi() {
        internalLock.synchronized {
            _internal = nil
        }
    }
}
