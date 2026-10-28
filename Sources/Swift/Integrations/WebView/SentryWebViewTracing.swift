#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import WebKit

/// Options for ``SentryWebViewTracing``.
///
/// Mirrors the `options` parameter of `sentryWebViewProps(options)` in the React Native SDK.
public struct SentryWebViewTracingOptions {
    /// The hosts whose pages receive the trace.
    ///
    /// A page matches when its hostname equals an entry or is a subdomain of it, for example
    /// `"example.com"` matches `example.com` and `app.example.com`. Entries are normalized to bare
    /// lowercase hostnames: whitespace, a scheme, a path, a port, a trailing dot, and a leading
    /// `*.` are stripped.
    ///
    /// - Warning: `allowedHosts` is a trust boundary. The injected `baggage` can carry release and
    ///   environment data, so only list hosts whose content you control. The script checks the page
    ///   host on every document load, but treat that check as defense in depth.
    public var allowedHosts: [String]

    /// Creates options for ``SentryWebViewTracing``.
    ///
    /// - Parameter allowedHosts: The hosts whose pages receive the trace.
    public init(allowedHosts: [String]) {
        self.allowedHosts = allowedHosts
    }
}

/// Connects traces of web content in a WebView with the app's trace.
///
/// ```swift
/// let configuration = WKWebViewConfiguration()
/// SentryWebViewTracing.addTracePropagation(
///     to: configuration,
///     options: SentryWebViewTracingOptions(allowedHosts: ["app.example.com"])
/// )
/// let webView = WKWebView(frame: .zero, configuration: configuration)
/// ```
///
/// Adds a user script that writes the current trace as `sentry-trace` and `baggage` `<meta>` tags
/// into the document before any page script runs. A `@sentry/browser` in the page then continues
/// the trace on pageload. The page must run `@sentry/browser` with `browserTracingIntegration` for
/// the connection to take effect.
///
/// The root span name (`sentry-transaction`) is removed from `baggage` because it is free-form
/// text that may contain user data. Only the main frame receives the tags.
///
/// The script holds a snapshot of the trace at the time of the call and is reused for every later
/// navigation. To propagate a newer trace, call `addTracePropagation` again: it replaces the script
/// Sentry added earlier and keeps the app's own scripts. If the call fails, no Sentry script is
/// left behind. Scripts apply from the next navigation.
public enum SentryWebViewTracing {
    /// Adds trace propagation to WebViews that use this user content controller.
    ///
    /// - Parameters:
    ///   - userContentController: The controller of the WebViews that receive the trace.
    ///   - options: The options, including the hosts whose pages receive the trace.
    /// - Returns: `true` if the script was added; `false` if `allowedHosts` has no valid entry or
    ///   the SDK is not enabled.
    @MainActor
    @discardableResult
    public static func addTracePropagation(
        to userContentController: WKUserContentController,
        options: SentryWebViewTracingOptions
    ) -> Bool {
        SentryWebViewTracePropagation.recordUsage(in: SentrySDK.isEnabled ? SentrySDKInternal.currentHub() : nil)
        return SentryWebViewTracePropagation.install(
            allowedHosts: options.allowedHosts,
            on: userContentController,
            hub: SentryWebViewTracePropagation.currentHub
        )
    }

    /// Adds trace propagation to WebViews created with this configuration.
    ///
    /// Forwards to the user content controller overload with the configuration's
    /// `userContentController`.
    ///
    /// - Parameters:
    ///   - configuration: The configuration of the WebViews that receive the trace.
    ///   - options: The options, including the hosts whose pages receive the trace.
    /// - Returns: `true` if the script was added.
    @MainActor
    @discardableResult
    public static func addTracePropagation(
        to configuration: WKWebViewConfiguration,
        options: SentryWebViewTracingOptions
    ) -> Bool {
        addTracePropagation(to: configuration.userContentController, options: options)
    }

    /// Adds trace propagation to this WebView, starting with the next navigation.
    ///
    /// Forwards to the user content controller overload with the WebView's user content
    /// controller.
    ///
    /// - Parameters:
    ///   - webView: The WebView that receives the trace.
    ///   - options: The options, including the hosts whose pages receive the trace.
    /// - Returns: `true` if the script was added.
    @MainActor
    @discardableResult
    public static func addTracePropagation(
        to webView: WKWebView,
        options: SentryWebViewTracingOptions
    ) -> Bool {
        addTracePropagation(to: webView.configuration.userContentController, options: options)
    }

#if compiler(>=6.2)
    /// Adds trace propagation to the SwiftUI `WebPage` created with this configuration.
    ///
    /// Call it before creating the `WebPage`, because a `WebPage` doesn't expose its configuration.
    /// A `WebView(url:)` creates its page internally, so create a `WebPage` with this configuration
    /// and pass it to `WebView(_:)` instead.
    ///
    /// - Parameters:
    ///   - configuration: The configuration of the `WebPage` that receives the trace.
    ///   - options: The options, including the hosts whose pages receive the trace.
    /// - Returns: `true` if the script was added.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @MainActor
    @discardableResult
    public static func addTracePropagation(
        to configuration: WebPage.Configuration,
        options: SentryWebViewTracingOptions
    ) -> Bool {
        addTracePropagation(to: configuration.userContentController, options: options)
    }
#endif
}

enum SentryWebViewTracePropagation {
    /// Identifies Sentry's script among the controller's user scripts. WebKit has no API to remove
    /// a single user script.
    static let scriptMarker = "/* sentry-webview-trace-propagation */"

    private static let transactionBaggageKey = "sentry-transaction"

    /// Reported in the SDK info as `WebViewTracePropagation`, matching the other SDKs.
    static let integrationName = "SentryWebViewTracePropagationIntegration"

    /// `nil` while the SDK is not running, so no trace is injected.
    static var currentHub: Hub? {
        SentrySDK.isEnabled ? SentryDependencyContainer.sharedInstance().hub : nil
    }

    /// Records feature adoption once per hub. Recorded on use rather than on success, like the
    /// other SDKs, so apps that wired the feature up count even when a call can't install.
    @MainActor
    static func recordUsage(in hub: SentryHubInternal?) {
        guard let hub = hub, !hub.hasIntegration(integrationName) else {
            return
        }
        hub.addInstalledIntegration(SentryWebViewTracePropagationIntegration(), name: integrationName)
    }

    /// Removes any previous Sentry script so a stale trace is never injected, then adds a fresh one
    /// before the app's own scripts.
    @MainActor
    @discardableResult
    static func install(allowedHosts: [String], on controller: WKUserContentController, hub: Hub?) -> Bool {
        let source = makeScriptSource(allowedHosts: allowedHosts, hub: hub)
        let appScripts = controller.userScripts.filter { !$0.source.hasPrefix(scriptMarker) }
        controller.removeAllUserScripts()

        if let source = source {
            // The page content world is required: `@sentry/browser` must see the tags.
            controller.addUserScript(WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                in: .page
            ))
        }
        // Scripts keep their content world, so re-adding them preserves the app's setup.
        appScripts.forEach { controller.addUserScript($0) }
        return source != nil
    }

    /// Returns the script that writes the trace into the page, or `nil` when there is nothing to
    /// inject.
    static func makeScriptSource(allowedHosts: [String], hub: Hub?) -> String? {
        var normalizedHosts: [String] = []
        for host in allowedHosts.map(normalizeHost) where !host.isEmpty && !normalizedHosts.contains(host) {
            normalizedHosts.append(host)
        }
        guard !normalizedHosts.isEmpty else {
            SentrySDKLog.warning("No valid allowedHosts provided; skipping WebView trace propagation.")
            return nil
        }
        guard let hub = hub, let options = hub.currentOptions else {
            SentrySDKLog.debug("SDK is not enabled; skipping WebView trace propagation.")
            return nil
        }

        let trace = SentryOutgoingTrace.current(scope: hub.scope, options: options)
        guard let hostsLiteral = jsonLiteral(normalizedHosts),
              let sentryTraceLiteral = jsonLiteral(sentryTraceValue(for: trace)),
              let baggageLiteral = jsonLiteral(baggageValue(for: trace)) else {
            SentrySDKLog.error("Failed to encode the WebView trace propagation script.")
            return nil
        }

        // Matches sentry-react-native's `sentryWebViewProps` and sentry-java's
        // `SentryWebViewTracing`. The script re-runs on every document load, so each navigation is
        // checked against its own host, and it does nothing if a `sentry-trace` tag already exists.
        return """
        \(scriptMarker)
        (function(){try{
        if(window.top!==window)return;
        var allowed=\(hostsLiteral);
        var host=(window.location&&window.location.hostname||'').toLowerCase();
        if(!host)return;
        if(!allowed.some(function(h){return host===h||host.slice(-(h.length+1))==='.'+h;}))return;
        if(document.querySelector('meta[name="sentry-trace"]'))return;
        var head=document.head||document.documentElement;
        if(!head)return;
        var set=function(n,c){if(!c)return;var m=document.createElement('meta');m.setAttribute('name',n);m.setAttribute('content',c);head.appendChild(m);};
        set('sentry-trace',\(sentryTraceLiteral));
        set('baggage',\(baggageLiteral));
        }catch(e){}})();
        true;
        """
    }

    /// The propagation context's header is marked as not sampled. The browser SDK would inherit
    /// that decision and drop its pageload, so the flag is omitted to let the page decide, matching
    /// the JavaScript SDK when no span is active.
    static func sentryTraceValue(for trace: SentryOutgoingTrace) -> String {
        guard !trace.isFromSpan else {
            return trace.traceHeader.value()
        }
        return TraceHeader(
            trace: trace.traceHeader.traceId,
            spanId: trace.traceHeader.spanId,
            sampled: .undecided
        ).value()
    }

    /// Returns the `baggage` header without `sentry-transaction`, or `nil` if nothing remains.
    static func baggageValue(for trace: SentryOutgoingTrace) -> String? {
        guard let header = trace.baggage?.toHTTPHeader(withOriginalBaggage: nil) else {
            return nil
        }
        var entries = SentryBaggageSerialization.decode(header)
        entries.removeValue(forKey: transactionBaggageKey)
        let baggage = SentryBaggageSerialization.encodeDictionary(entries)
        return baggage.isEmpty ? nil : baggage
    }

    /// Normalizes an `allowedHosts` entry to a bare lowercase hostname that compares equal to the
    /// page's `location.hostname`, for example `" https://*.App.Example.com:8080/x "` to
    /// `"app.example.com"`. IPv6 literals are bracketed like `location.hostname`, for example
    /// `"::1"` to `"[::1]"`.
    static func normalizeHost(_ host: String) -> String {
        var value = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if let scheme = value.range(of: "^[a-z][a-z0-9+.-]*://", options: [.regularExpression, .caseInsensitive]) {
            value.removeSubrange(scheme)
        }
        if let pathStart = value.firstIndex(where: { "/?#".contains($0) }) {
            value = String(value[..<pathStart])
        }

        // A colon can be a port separator or part of an IPv6 literal.
        if let closingBracket = value.firstIndex(of: "]") {
            value = String(value[...closingBracket])
        } else if value.filter({ $0 == ":" }).count > 1 {
            value = "[\(value)]"
        } else if let port = value.range(of: ":\\d+$", options: .regularExpression) {
            value.removeSubrange(port)
        }

        if value.hasSuffix(".") {
            value.removeLast()
        }
        // Subdomains always match, so a wildcard is redundant. Kept, it would never match.
        while value.hasPrefix("*.") {
            value.removeFirst(2)
        }
        return value.lowercased()
    }

    /// Encodes a value as a JavaScript literal, escaping any characters that could break out of it.
    private static func jsonLiteral(_ value: Any?) -> String? {
        guard let value = value else {
            return "null"
        }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

/// Marks WebView trace propagation as used in the SDK info. It has no lifecycle, because the
/// feature is a per-WebView call rather than an integration installed at SDK start.
final class SentryWebViewTracePropagationIntegration: NSObject, SentryIntegrationProtocol {
    func uninstall() {}
}
#endif
