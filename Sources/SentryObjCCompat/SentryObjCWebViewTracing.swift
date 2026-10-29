// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import WebKit

@objc(SentryObjCWebViewTracingOptions) public final class SentryObjCWebViewTracingOptions: NSObject {
    @objc public var allowedHosts: [String]

    @objc public init(allowedHosts: [String]) {
        self.allowedHosts = allowedHosts
        super.init()
    }

    internal func toSentryWebViewTracingOptions() -> SentryWebViewTracingOptions {
        SentryWebViewTracingOptions(allowedHosts: allowedHosts)
    }
}

@objc(SentryObjCWebViewTracing) public final class SentryObjCWebViewTracing: NSObject {
    @objc(addTracePropagationToUserContentController:options:)
    @discardableResult
    public static func addTracePropagation(
        to userContentController: WKUserContentController,
        options: SentryObjCWebViewTracingOptions
    ) -> Bool {
        onMainActor {
            SentryWebViewTracing.addTracePropagation(to: userContentController, options: options.toSentryWebViewTracingOptions())
        }
    }

    @objc(addTracePropagationToConfiguration:options:)
    @discardableResult
    public static func addTracePropagation(
        to configuration: WKWebViewConfiguration,
        options: SentryObjCWebViewTracingOptions
    ) -> Bool {
        onMainActor {
            SentryWebViewTracing.addTracePropagation(to: configuration, options: options.toSentryWebViewTracingOptions())
        }
    }

    @objc(addTracePropagationToWebView:options:)
    @discardableResult
    public static func addTracePropagation(
        to webView: WKWebView,
        options: SentryObjCWebViewTracingOptions
    ) -> Bool {
        onMainActor {
            SentryWebViewTracing.addTracePropagation(to: webView, options: options.toSentryWebViewTracingOptions())
        }
    }

    /// Objective-C callers aren't checked for main actor isolation at compile time, so a call off
    /// the main thread returns `false` instead of trapping.
    private static func onMainActor(_ body: @MainActor () -> Bool) -> Bool {
        guard Thread.isMainThread else {
            return false
        }
        return MainActor.assumeIsolated(body)
    }
}
#endif
// swiftlint:enable missing_docs
