#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import WebKit

extension SentrySwizzleMethod where Receiver: WKWebView, Arguments == SentrySwizzleObjectArguments1, Result == AnyObject? {
    /// Describes `-[WKWebView loadRequest:]`.
    /// - SeeAlso: `WKWebView.load(_:)` accepting a `URLRequest`.
    static func webViewLoadRequest(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.load(_:) as (WKWebView) -> (URLRequest) -> WKNavigation?),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object])
        )
    }
}

extension SentrySwizzleMethod where Receiver: WKWebView, Arguments == SentrySwizzleObjectArguments2, Result == AnyObject? {
    /// Describes `-[WKWebView loadHTMLString:baseURL:]`.
    /// - SeeAlso: `WKWebView.loadHTMLString(_:baseURL:)`
    static func webViewLoadHTMLString(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.loadHTMLString(_:baseURL:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object])
        )
    }

    /// Describes `-[WKWebView loadFileURL:allowingReadAccessToURL:]`.
    /// - SeeAlso: `WKWebView.loadFileURL(_:allowingReadAccessTo:)`
    static func webViewLoadFileURL(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.loadFileURL(_:allowingReadAccessTo:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object])
        )
    }

    /// Describes `-[WKWebView loadFileRequest:allowingReadAccessToURL:]`.
    /// - SeeAlso: `WKWebView.loadFileRequest(_:allowingReadAccessTo:)`
    static func webViewLoadFileRequest(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.loadFileRequest(_:allowingReadAccessTo:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object])
        )
    }

    /// Describes `-[WKWebView loadSimulatedRequest:responseHTMLString:]`.
    /// - SeeAlso: `WKWebView.loadSimulatedRequest(_:responseHTML:)`
    static func webViewLoadSimulatedRequestHTML(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.loadSimulatedRequest(_:responseHTML:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object])
        )
    }
}

extension SentrySwizzleMethod where Receiver: WKWebView, Arguments == SentrySwizzleObjectArguments3, Result == AnyObject? {
    /// Describes `-[WKWebView loadSimulatedRequest:response:responseData:]`.
    /// - SeeAlso: `WKWebView.loadSimulatedRequest(_:response:responseData:)`
    static func webViewLoadSimulatedRequestData(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.loadSimulatedRequest(_:response:responseData:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object, .object])
        )
    }
}

extension SentrySwizzleMethod where Receiver: WKWebView, Arguments == SentrySwizzleObjectArguments4, Result == AnyObject? {
    /// Describes `-[WKWebView loadData:MIMEType:characterEncodingName:baseURL:]`.
    /// - SeeAlso: `WKWebView.load(_:mimeType:characterEncodingName:baseURL:)`
    static func webViewLoadData(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(WKWebView.load(_:mimeType:characterEncodingName:baseURL:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object, .object, .object])
        )
    }
}
#endif
