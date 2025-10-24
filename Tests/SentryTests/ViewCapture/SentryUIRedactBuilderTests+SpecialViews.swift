#if os(iOS) && !targetEnvironment(macCatalyst)
import AVKit
import Foundation
import PDFKit
import SafariServices
@_spi(Private) @testable import Sentry
import SentryTestUtils
import SnapshotTesting
import SwiftUI
import UIKit
import WebKit
import XCTest

/// See `SentryUIRedactBuilderTests.swift` for more information on how to print the internal view hierarchy of a view.
class SentryUIRedactBuilderTests_SpecialViews: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name
    private func getSut(maskAllText: Bool, maskAllImages: Bool) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages
        ))
    }

    // MARK: - PDF View

    private func setupPDFViewFixture() -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let pdfView = PDFView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(pdfView)

        return rootView

        // View Hierarchy:
        // ---------------
        // <UIView: 0x101b98120; frame = (0 0; 100 100); layer = <CALayer: 0x600000c9f390>>
        //   | <PDFView: 0x101d256e0; frame = (20 20; 40 40); gestureRecognizers = <NSArray: 0x600000cea190>; backgroundColor = <UIDynamicSystemColor: 0x60000173f180; name = secondarySystemBackgroundColor>; layer = <CALayer: 0x600000ce80f0>>
        //   |    | <PDFScrollView: 0x104028400; baseClass = UIScrollView; frame = (0 0; 40 40); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x600000ce9d70>; layer = <CALayer: 0x600000ce8a20>; contentOffset: {0, 0}; contentSize: {0, 0}; adjustedContentInset: {0, 0, 0, 0}>
    }

    func testRedact_withPDFView_withMaskingEnabled_shouldBeRedacted() throws {
        // -- Arrange --
        let rootView = setupPDFViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let pdfRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(pdfRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(pdfRegion.type, .redact)
        XCTAssertEqual(pdfRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(pdfRegion.color)

        let pdfScrollViewRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(pdfScrollViewRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(pdfScrollViewRegion.type, .redact)
        XCTAssertEqual(pdfScrollViewRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(pdfScrollViewRegion.color)

        // Assert no additional regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedact_withPDFView_withMaskingDisabled_shouldBeRedacted() throws {
        // -- Arrange --
        let rootView = setupPDFViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let pdfRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(pdfRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(pdfRegion.type, .redact)
        XCTAssertEqual(pdfRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(pdfRegion.color)

        let pdfScrollViewRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(pdfScrollViewRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(pdfScrollViewRegion.type, .redact)
        XCTAssertEqual(pdfScrollViewRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(pdfScrollViewRegion.color)

        // Assert no additional regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - WKWebView

    private func setupWKWebViewFixture() -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let webView = WKWebView(frame: .init(x: 20, y: 20, width: 40, height: 40), configuration: .init())
        rootView.addSubview(webView)

        return rootView

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105b3ac60; frame = (0 0; 100 100); layer = <CALayer: 0x600000c4fa50>>
        //    | <WKWebView: 0x121819400; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce8120>>
        //    |    | <WKScrollView: 0x106883000; baseClass = UIScrollView; frame = (0 0; 40 40); clipsToBounds = YES; gestureRecognizers = <NSArray: 0x600000cf1560>; backgroundColor = kCGColorSpaceModelRGB 1 1 1 1; layer = <CALayer: 0x600000cf0450>; contentOffset: {0, 0}; contentSize: {0, 0}; adjustedContentInset: {0, 0, 0, 0}>
        //    |    |    | <WKContentView: 0x121822800; frame = (0 0; 40 40); anchorPoint = (0, 0); layer = <CALayer: 0x600000ce8750>>
        //    |    |    |    | <UIView: 0x121012580; frame = (0 0; 0 0); anchorPoint = (0, 0); clipsToBounds = YES; layer = <CALayer: 0x600000cf8960>>
        //    |    |    |    |    | <UIView: 0x1210123e0; frame = (0 0; 0 0); autoresize = W+H; layer = <CALayer: 0x600000cf8930>>
        //    |    |    |    | <WKVisibilityPropagationView: 0x105c21580; frame = (0 0; 0 0); layer = <CALayer: 0x600000cf01b0>>
        //    |    |    | <_UIScrollViewScrollIndicator: 0x105c33170; frame = (34 30; 3 7); alpha = 0; autoresize = LM; layer = <CALayer: 0x600000cf0c30>>
        //    |    |    |    | <UIView: 0x105c2b5f0; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0.5; layer = <CALayer: 0x600000cf1830>>
        //    |    |    | <_UIScrollViewScrollIndicator: 0x105c3eb90; frame = (30 34; 7 3); alpha = 0; autoresize = TM; layer = <CALayer: 0x600000cf1620>>
        //    |    |    |    | <UIView: 0x105c3cf60; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0.5; layer = <CALayer: 0x600000cf1770>>
    }

    func testRedact_withWKWebView_withMaskingEnabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = setupWKWebViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0)) // WKWebView
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.element(at: 1)) // WKScrollView
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedact_withWKWebView_withMaskingDisabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = setupWKWebViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40)) // WKWebView
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40)) // WKScrollView
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - UIWebView

    private func setupUIWebViewFixture() throws -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        // The UIWebView initializers are marked as unavailable, so we use createFakeView.
        // Note: All fake views are kept alive to prevent dealloc crashes (see createFakeView docs).
        let webView = try XCTUnwrap(createFakeView(
            type: UIView.self,
            name: "UIWebView",
            frame: .init(x: 20, y: 20, width: 40, height: 40)
        ))
        rootView.addSubview(webView)

        return rootView

        // View Hierarchy:
        // ---------------
        // <UIView: 0x106c20400; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf08d0>>
        //    | <UIWebView: 0x103a76a00; frame = (20 20; 40 40); layer = <CALayer: 0x600000cf1b60>>
    }

    func testRedact_withUIWebView_withMaskingEnabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = try setupUIWebViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUIWebView_withMaskingDisabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = try setupUIWebViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - SFSafariView Redaction

    private func setupSFSafariViewControllerFixture() throws -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let safariViewController = SFSafariViewController(url: URL(string: "https://example.com")!)
        let safariView = try XCTUnwrap(safariViewController.view)
        safariView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(safariView)

        return rootView

        // View Hierarchy:
        // ---------------
        // == iOS 26 & 18 & 17 ==
        // <UIView: 0x10294c8e0; frame = (0 0; 100 100); layer = <CALayer: 0x600000ccab50>>
        //   | <SFSafariView: 0x102b39d30; frame = (20 20; 40 40); layer = <CALayer: 0x600000cd2490>>
        //
        // == iOS 16 & 15 ==
        // <UIView: 0x12e717620; frame = (0 0; 100 100); layer = <CALayer: 0x600001a31320>>
        //    | <SFSafariView: 0x12e60ef40; frame = (20 20; 40 40); layer = <CALayer: 0x600001a5b8a0>>
        //    |    | <SFSafariLaunchPlaceholderView: 0x12e60f600; frame = (0 0; 40 40); autoresize = W+H; backgroundColor = <UIDynamicSystemColor: 0x600000f4d800; name = systemBackgroundColor>; layer = <CALayer: 0x600001a5b960>>
        //    |    |    | <UINavigationBar: 0x12e60f9a0; frame = (0 0; 0 0); opaque = NO; layer = <CALayer: 0x600001a5bc60>> delegate=0x12e60f600 no-scroll-edge-support
        //    |    |    | <UIToolbar: 0x12e7199b0; frame = (0 0; 0 0); layer = <CALayer: 0x600001a229e0>>
    }

    private func assertSFSafariViewControllerRegions(regions: [SentryRedactRegion]) throws {
        if #available(iOS 17, *) { // iOS 26  & 18 & 17
            let region = try XCTUnwrap(regions.element(at: 0))
            XCTAssertNil(region.color)
            XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(region.type, .redact)
            XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            // Assert that there are no other regions
            XCTAssertEqual(regions.count, 1)
        } else if #available(iOS 15, *) { // iOS 16 & 15
            let toolbarRegion = try XCTUnwrap(regions.element(at: 0)) // UIToolbar
            XCTAssertNil(toolbarRegion.color)
            XCTAssertEqual(toolbarRegion.size, CGSize(width: 0, height: 0))
            XCTAssertEqual(toolbarRegion.type, .redact)
            XCTAssertEqual(toolbarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let navigationBarRegion = try XCTUnwrap(regions.element(at: 1)) // UINavigationBar
            XCTAssertNil(navigationBarRegion.color)
            XCTAssertEqual(navigationBarRegion.size, CGSize(width: 0, height: 0))
            XCTAssertEqual(navigationBarRegion.type, .redact)
            XCTAssertEqual(navigationBarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let placeholderRegion = try XCTUnwrap(regions.element(at: 2)) // SFSafariLaunchPlaceholderView
            XCTAssertNil(placeholderRegion.color)
            XCTAssertEqual(placeholderRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(placeholderRegion.type, .redact)
            XCTAssertEqual(toolbarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let safariViewRegion = try XCTUnwrap(regions.element(at: 3)) // SFSafariView
            XCTAssertNil(safariViewRegion.color)
            XCTAssertEqual(safariViewRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(safariViewRegion.type, .redact)
            XCTAssertEqual(safariViewRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            // Assert that there are no other regions
            XCTAssertEqual(regions.count, 4)
        } else {
            throw XCTSkip("Redaction of SFSafariViewController is not tested on iOS versions below 15")
        }
    }

    func testRedact_withSFSafariView_withMaskingEnabled_shouldRedactViewHierarchy() throws {
#if targetEnvironment(macCatalyst)
        throw XCTSkip("SFSafariViewController opens system browser on macOS, nothing to redact, skipping test")
#else
        // -- Arrange --
        let rootView = try setupSFSafariViewControllerFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        try assertSFSafariViewControllerRegions(regions: result)
#endif
    }

    func testRedact_withSFSafariView_withMaskingDisabled_shouldRedactView() throws {
#if targetEnvironment(macCatalyst)
        throw XCTSkip("SFSafariViewController opens system browser on macOS, nothing to redact, skipping test")
#else
        // -- Arrange --
        let rootView = try setupSFSafariViewControllerFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        try assertSFSafariViewControllerRegions(regions: result)
#endif
    }

    // MARK: - AVPlayer Redaction

    private func setupAVPlayerViewControllerFixture() throws -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let avPlayerViewController = AVPlayerViewController()
        let avPlayerView = try XCTUnwrap(avPlayerViewController.view)
        avPlayerView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(avPlayerView)

        return rootView

        // View Hierarchy:
        // ---------------
        // <UIView: 0x130d0d4f0; frame = (0 0; 100 100); layer = <CALayer: 0x600003654760>>
        //    | <AVPlayerView: 0x130e27580; frame = (20 20; 40 40); autoresize = W+H; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <AVPresentationContainerViewLayer: 0x600003912400>>
    }

    private func assertAVPlayerViewControllerRegions(regions: [SentryRedactRegion]) throws {
        let region = try XCTUnwrap(regions.element(at: 0))
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(region.color)

        // Assert that there are no other regions
        XCTAssertEqual(regions.count, 1)
    }

    func testRedact_withAVPlayerViewController_shouldBeRedacted() throws {
        // -- Arrange --
        let rootView = try setupAVPlayerViewControllerFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        try assertAVPlayerViewControllerRegions(regions: result)
    }

    func testRedact_withAVPlayerViewControllerEvenWithMaskingDisabled_shouldBeRedacted() throws {
        // -- Arrange --
        let rootView = try setupAVPlayerViewControllerFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        try assertAVPlayerViewControllerRegions(regions: result)
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
