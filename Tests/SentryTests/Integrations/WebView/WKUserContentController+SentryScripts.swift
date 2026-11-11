#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import WebKit

extension WKUserContentController {
    /// The user scripts that Sentry's WebView trace propagation installed.
    @MainActor
    var sentryScripts: [WKUserScript] {
        userScripts.filter { $0.source.hasPrefix(SentryWebViewTracePropagation.scriptMarker) }
    }
}
#endif
