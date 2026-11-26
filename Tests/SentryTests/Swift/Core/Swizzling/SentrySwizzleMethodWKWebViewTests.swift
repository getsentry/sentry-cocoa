#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import WebKit
import XCTest

final class SentrySwizzleMethodWKWebViewTests: XCTestCase {
    func testLoadRequest_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments1<NSURLRequest>, WKNavigation?>.webViewLoadRequest(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadRequest:")
        XCTAssertEqual(method.signature.description, "@@:@")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadHTMLString_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments2<NSString, NSURL>, WKNavigation?>.webViewLoadHTMLString(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadHTMLString:baseURL:")
        XCTAssertEqual(method.signature.description, "@@:@@")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadFileURL_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments2<NSURL, NSURL>, WKNavigation?>.webViewLoadFileURL(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadFileURL:allowingReadAccessToURL:")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadFileRequest_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments2<NSURLRequest, NSURL>, WKNavigation?>.webViewLoadFileRequest(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadFileRequest:allowingReadAccessToURL:")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadSimulatedRequestHTML_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments2<NSURLRequest, NSString>, WKNavigation?>.webViewLoadSimulatedRequestHTML(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadSimulatedRequest:responseHTMLString:")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadSimulatedRequestData_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments3<NSURLRequest, URLResponse, NSData>, WKNavigation?>.webViewLoadSimulatedRequestData(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadSimulatedRequest:response:responseData:")
        XCTAssertEqual(method.signature.description, "@@:@@@")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadData_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments4<NSData, NSString, NSString, NSURL>, WKNavigation?>.webViewLoadData(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "loadData:MIMEType:characterEncodingName:baseURL:")
        XCTAssertEqual(method.signature.description, "@@:@@@@")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testReload_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, Void, WKNavigation?>.webViewReload(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "reload")
        XCTAssertEqual(method.signature.description, "@@:")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testReloadFromOrigin_shouldMatchRuntimeSignature() {
        let method = SentrySwizzleMethod<WKWebView, Void, WKNavigation?>.webViewReloadFromOrigin(WKWebView.self)

        XCTAssertEqual(NSStringFromSelector(method.selector), "reloadFromOrigin")
        XCTAssertEqual(method.signature.description, "@@:")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }

    func testLoadRequest_whenArgumentCountIsWrong_shouldRejectSignature() {
        let method = SentrySwizzleMethod<WKWebView, SentrySwizzleObjectArguments1<NSURLRequest>, WKNavigation?>(
            selector: #selector(WKWebView.load(_:) as (WKWebView) -> (URLRequest) -> WKNavigation?),
            receiver: WKWebView.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object])
        )

        XCTAssertFalse(SentryTypedSwizzle.validate(in: WKWebView.self, method: method))
    }
}
#endif
