#if os(iOS)
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

// The following command was used to derive the view hierarchy:
//
// ```
// (lldb) po rootView.value(forKey: "recursiveDescription")!
// ```
class SentryUIRedactBuilderTests_UIKit: SentryUIRedactBuilderTests {
    private var rootView: UIView!

    private func getSut(maskAllText: Bool, maskAllImages: Bool) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages
        ))
    }

    override func setUp() {
        rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    // MARK: - UILabel Redaction

    private func setupUILabelFixture(textColor: UIColor? = nil) {
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = textColor ?? .purple
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103e44920; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce1560>>
        //   | <UILabel: 0x103e48070; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c0a700>>
    }

    func testRedact_withUILabel_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        setupUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        // For UILabel we can use the text color directly to render the redaction geometry
        XCTAssertEqual(region.color, .purple)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUILabel_withMaskAllTextEnabled_withTransparentForegroundColor_shouldNotUseTransparentColor() throws {
        // -- Arrange --
        setupUILabelFixture(
            textColor: UIColor.purple.withAlphaComponent(0.5) // Any color with an opacity below 1.0 is considered transparent
        )

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        // For UILabel we can derive which color should be used to render the redaction geometry
        XCTAssertEqual(region.color, .purple)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUILabel_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        setupUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }

    /// This test is to ensure that the option `maskAllImages` does not affect the UILabel redaction
    func testRedact_withUILabel_withMaskAllImagesDisabled_shouldRedactView() throws {
        // -- Arrange --
        setupUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
    }

    // - MARK: - UITextView Redaction

    private func setupUITextViewFixture() {
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textView.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // == iOS 26 & 18 ==
        // <UIView: 0x12dd09000; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce91d0>>
        //   | <UITextView: 0x10780a400; frame = (20 20; 40 40); text = ''; clipsToBounds = YES; gestureRecognizers = <NSArray: 0x600000cdfd50>; backgroundColor = <UIDynamicSystemColor: 0x600001778100; name = systemBackgroundColor>; layer = <CALayer: 0x600000ceb090>; contentOffset: {0, 0}; contentSize: {40, 32}; adjustedContentInset: {0, 0, 0, 0}>
        //   |    | <_UITextLayoutView: 0x12dd0ba00; frame = (0 0; 0 0); layer = <CALayer: 0x600000cebfc0>>
        //   |    | <<_UITextContainerView: 0x12dd0b440; frame = (0 0; 40 30); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000ce9350>> minSize = {0, 0}, maxSize = {1.7976931348623157e+308, 1.7976931348623157e+308}, textContainer = <NSTextContainer: 0x600003518210 size = (40.000000,inf); widthTracksTextView = YES; heightTracksTextView = NO>; exclusionPaths = 0x1e5cbb9d0; lineBreakMode = 0>
        //   |    |    | <_UITextLayoutCanvasView: 0x12dd0b680; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000ce9ad0>>
        //   |    |    |    | <UIView: 0x13250a680; frame = (0 0; 0 0); layer = <CALayer: 0x600000ccf840>>
        //
        // == iOS 17 ==
        // <UIView: 0x105c3bd30; frame = (0 0; 100 100); layer = <CALayer: 0x600000272dc0>>
        //   | <UITextView: 0x107042800; frame = (20 20; 40 40); text = ''; clipsToBounds = YES; gestureRecognizers = <NSArray: 0x600000da6b80>; backgroundColor = <UIDynamicSystemColor: 0x6000017d2600; name = systemBackgroundColor>; layer = <CALayer: 0x60000027a320>; contentOffset: {0, 0}; contentSize: {40, 32}; adjustedContentInset: {0, 0, 0, 0}>
        //   |    | <_UITextLayoutView: 0x105a04680; frame = (0 0; 0 0); layer = <CALayer: 0x6000002a0d20>>
        //   |    | <UIView: 0x105a09e60; frame = (0 0; 0 0); layer = <CALayer: 0x6000002a2520>>
        //   |    | <<_UITextContainerView: 0x105a11ba0; frame = (0 0; 40 30); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x6000002a0400>> minSize = {0, 0}, maxSize = {1.7976931348623157e+308, 1.7976931348623157e+308}, textContainer = <NSTextContainer: 0x600003512310 size = (40.000000,inf); widthTracksTextView = YES; heightTracksTextView = NO>; exclusionPaths = 0x1e4de1c08; lineBreakMode = 0>
        //   |    |    | <_UITextLayoutCanvasView: 0x105a44770; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x6000002a0520>>
        //
        // == iOS 16 ==
        // <UIView: 0x11d305d40; frame = (0 0; 100 100); layer = <CALayer: 0x60000142e620>>
        //   | <UITextView: 0x120008c00; frame = (20 20; 40 40); clipsToBounds = YES; gestureRecognizers = <NSArray: 0x600001b28cf0>; backgroundColor = <UIDynamicSystemColor: 0x6000001f03c0; name = systemBackgroundColor>; layer = <CALayer: 0x600001465040>; contentOffset: {0, 0}; contentSize: {40, 32}; adjustedContentInset: {0, 0, 0, 0}>
        //   |    | <_UITextLayoutView: 0x11d20b550; frame = (0 0; 0 0); layer = <CALayer: 0x60000142fb60>>
        //   |    | <<_UITextContainerView: 0x11d307950; frame = (0 0; 40 30); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x60000143d0a0>> minSize = {0, 0}, maxSize = {1.7976931348623157e+308, 1.7976931348623157e+308}, textContainer = <NSTextContainer: 0x600002564a00 size = (40.000000,inf); widthTracksTextView = YES; heightTracksTextView = NO>; exclusionPaths = 0x1bbd8b8a8; lineBreakMode = 0>
        //   |    |    | <_UITextLayoutCanvasView: 0x11d307d70; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x6000014ca1c0>>
        //   |    |    |    | <_UITextLayoutFragmentView: 0x11d20c210; frame = (0 8; 10 14); opaque = NO; layer = <CALayer: 0x600001430900>>
    }

    func testRedact_withUITextView_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        setupUITextViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUITextView_withMaskAllTextDisabled_shouldNotRedactView() throws {
        // -- Arrange --
        setupUITextViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region1 = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region1.color)
        XCTAssertEqual(region1.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region1.type, .clipBegin)
        XCTAssertEqual(region1.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .clipEnd)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // The text view is marked as opaque and will therefore cause a clip out of its frame
        let region3 = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region3.type, .clipOut)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 3)
    }

    func testRedact_withUITextView_withMaskAllImagesDisabled_shouldRedactView() throws {
        // -- Arrange --
        setupUITextViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - UITextField Redaction

    private func setupUITextFieldFixture() {
        let textField = UITextField(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textField.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textField)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x104151d70; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf0ab0>>
        // | <UITextField: 0x104842200; frame = (20 20; 40 40); text = ''; opaque = NO; borderStyle = None; background = <_UITextFieldNoBackgroundProvider: 0x600000030670: textfield=<UITextField: 0x104842200>>; layer = <CALayer: 0x600000cf21f0>>
        // |    | <_UITextLayoutCanvasView: 0x104241040; frame = (0 0; 0 0); layer = <CALayer: 0x600000cee4f0>>
        
    }

    func testRedact_withUITextField_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        setupUITextFieldFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region1 = try XCTUnwrap(result.element(at: 0)) // _UITextLayoutCanvasView
        XCTAssertNil(region1.color)// The text color of UITextView is not used for redaction
        XCTAssertEqual(region1.size, CGSize(width: 0, height: 0))
        XCTAssertEqual(region1.type, .redact)
        XCTAssertEqual(region1.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.element(at: 1)) // UITextField
        XCTAssertNil(region2.color) // The text color of UITextView is not used for redaction
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedact_withUITextField_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        setupUITextFieldFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withUITextField_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        setupUITextFieldFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - UIImageView Redaction

    private func setupUIImageViewFixture() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10482a7e0; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce60a0>>
        //   | <UIImageView: 0x11b1632d0; frame = (20 20; 40 40); opaque = NO; userInteractionEnabled = NO; image = <UIImage:0x60000301d290 CGImage anonymous; (40 40)@3>; layer = <CALayer: 0x600000ce6460>>
    }

    func testRedact_withUIImageView_withMaskAllImagesEnabled_shouldRedactView() throws {
        // -- Arrange --
        setupUIImageViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUIImageView_withMaskAllImagesDisabled_shouldNotRedactView() {
        // -- Arrange --
        setupUIImageViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withUIImageView_withMaskAllTextDisabled_shouldRedactView() {
        // -- Arrange --
        setupUIImageViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUIImageView_withImageFromBundle_shouldNotRedactView() throws {
        // The check for bundled image only works for iOS 16 and above
        // For others versions all images will be redacted
        guard #available(iOS 16, *) else {
            throw XCTSkip("This test only works on iOS 16 and above")
        }

        // -- Arrange --
        let imageView = UIImageView(image: .add)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10422db10; frame = (0 0; 100 100); layer = <CALayer: 0x600000cce220>>
        //   | <UIImageView: 0x103554b20; frame = (20 20; 40 40); opaque = NO; userInteractionEnabled = NO; image = <UIImage:0x600003001050 symbol "plus.circle.fill"; (20 19)@3{2}>; layer = <CALayer: 0x600000ce56e0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testUIImageViewSmallImage_shouldNotRedact() {
        // -- Arrange --
        // Create a tiny image (below 10x10 threshold)
        let tiny = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 5)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 5, height: 5))
        }
        let imageView = UIImageView(image: tiny)
        imageView.frame = CGRect(x: 10, y: 10, width: 20, height: 20)
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10481c670; frame = (0 0; 100 100); layer = <CALayer: 0x600000c73b70>>
        //   | <UIImageView: 0x104c3f230; frame = (10 10; 20 20); opaque = NO; userInteractionEnabled = NO; image = <UIImage:0x600003010a20 CGImage anonymous; (5 5)@3>; layer = <CALayer: 0x600000cc3690>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - UIWebView

    private func setupUIWebViewFixture() throws {
        // The UIWebView initializer are marked as unavailable, therefore we need to create a fake view
        let webView = try XCTUnwrap(createFakeView(
            type: UIView.self,
            name: "UIWebView",
            frame: .init(x: 20, y: 20, width: 40, height: 40)
        ))
        rootView.addSubview(webView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x106c20400; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf08d0>>
        //    | <UIWebView: 0x103a76a00; frame = (20 20; 40 40); layer = <CALayer: 0x600000cf1b60>>
    }

    func testRedact_withUIWebView_withMaskingEnabled_shouldRedactView() throws {
        // -- Arrange --
        try setupUIWebViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
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
        try setupUIWebViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 1)
    }
}

#endif // os(iOS)
