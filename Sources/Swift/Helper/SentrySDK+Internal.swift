import Foundation

extension SentrySDK {
    /// APIs for hybrid SDKs (React Native, Flutter, .NET, Unity).
    ///
    /// These APIs may change in any minor release without deprecation.
    /// App developers should use the standard `SentrySDK` API instead.
    @_spi(Private) public static let `internal` = SentryInternalApi()
}
