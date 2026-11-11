#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import WebKit
import XCTest

final class SentryWebViewTraceRefresherProxyTests: XCTestCase {

    func testSetTarget_shouldReturnTarget() {
        // -- Arrange --
        let sut = SentryWebViewTraceRefresherProxy()
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil })

        // -- Act --
        sut.setTarget(refresher)

        // -- Assert --
        XCTAssertTrue(sut.target === refresher)
    }

    func testRemoveTarget_whenTargetIsCurrent_shouldRemoveIt() {
        // -- Arrange --
        let sut = SentryWebViewTraceRefresherProxy()
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil })
        sut.setTarget(refresher)

        // -- Act --
        sut.removeTarget(refresher)

        // -- Assert --
        XCTAssertNil(sut.target)
    }

    func testRemoveTarget_whenNewerTargetIsCurrent_shouldKeepNewerTarget() {
        // -- Arrange --
        let sut = SentryWebViewTraceRefresherProxy()
        let older = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil })
        let newer = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil })
        sut.setTarget(older)
        sut.setTarget(newer)

        // -- Act --
        sut.removeTarget(older)

        // -- Assert --
        XCTAssertTrue(sut.target === newer)
    }

    func testTarget_whenTargetDeallocated_shouldReturnNil() {
        // -- Arrange --
        let sut = SentryWebViewTraceRefresherProxy()

        // -- Act --
        autoreleasepool {
            sut.setTarget(SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil }))
        }

        // -- Assert --
        XCTAssertNil(sut.target)
    }
}
#endif
