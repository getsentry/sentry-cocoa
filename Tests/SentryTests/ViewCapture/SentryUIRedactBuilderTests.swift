#if os(iOS)
import AVKit
import Foundation
import PDFKit
import SafariServices
@testable import Sentry
import SentryTestUtils
import UIKit
import WebKit
import XCTest

/*
 * Mocked RCTTextView to test the redaction of text from React Native apps.
 */
@objc(RCTTextView)
class RCTTextView: UIView {
}

/*
 * Mocked RCTParagraphComponentView to test the redaction of text from React Native apps.
 */
@objc(RCTParagraphComponentView)
class RCTParagraphComponentView: UIView {
}

/*
 * Mocked RCTImageView to test the redaction of images from React Native apps.
 */
@objc(RCTImageView)
class RCTImageView: UIView {
}

// The following command was used to derive the view hierarchy:
//
// ```
// (lldb) po rootView.value(forKey: "recursiveDescription")!
// ```
class SentryUIRedactBuilderTests: XCTestCase {
    private class CustomVisibilityView: UIView {
        class CustomLayer: CALayer {
            override var opacity: Float {
                get { 0.5 }
                set { }
            }
        }
        override class var layerClass: AnyClass {
            return CustomLayer.self
        }
    }

    private var rootView: UIView!

    private func getSut(maskAllText: Bool, maskAllImages: Bool, maskedViewClasses: [AnyClass] = []) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            maskedViewClasses: maskedViewClasses
        ))
    }

    override func setUp() {
        rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testRedact_withNoSensitiveViews_shouldNotRedactAnything() {
        // -- Arrange --
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - UILabel Redaction

    func testRedact_withUILabel_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103e44920; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce1560>>
        // | <UILabel: 0x103e48070; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c0a700>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
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
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple.withAlphaComponent(0.5) // Any color with an opacity below 1.0 is considered transparent
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103e44920; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce1560>>
        // | <UILabel: 0x103e48070; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c0a700>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
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
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103e44920; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce1560>>
        // | <UILabel: 0x103e48070; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c0a700>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withUILabel_withMaskAllImagesDisabled_shouldRedactView() throws {
        // This test is to ensure that the option `maskAllImages` does not affect the UILabel redaction
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103e44920; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce1560>>
        // | <UILabel: 0x103e48070; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c0a700>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // - MARK: - UITextView Redaction

    func testRedact_withUITextView_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textView.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12dd09000; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce91d0>>
        // | <UITextView: 0x10780a400; frame = (20 20; 40 40); text = ''; clipsToBounds = YES; gestureRecognizers = <NSArray: 0x600000cdfd50>; backgroundColor = <UIDynamicSystemColor: 0x600001778100; name = systemBackgroundColor>; layer = <CALayer: 0x600000ceb090>; contentOffset: {0, 0}; contentSize: {40, 32}; adjustedContentInset: {0, 0, 0, 0}>
        // |    | <_UITextLayoutView: 0x12dd0ba00; frame = (0 0; 0 0); layer = <CALayer: 0x600000cebfc0>>
        // |    | <<_UITextContainerView: 0x12dd0b440; frame = (0 0; 40 30); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000ce9350>> minSize = {0, 0}, maxSize = {1.7976931348623157e+308, 1.7976931348623157e+308}, textContainer = <NSTextContainer: 0x600003518210 size = (40.000000,inf); widthTracksTextView = YES; heightTracksTextView = NO>; exclusionPaths = 0x1e5cbb9d0; lineBreakMode = 0>
        // |    |    | <_UITextLayoutCanvasView: 0x12dd0b680; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000ce9ad0>>
        // |    |    |    | <UIView: 0x13250a680; frame = (0 0; 0 0); layer = <CALayer: 0x600000ccf840>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
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
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textView.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x1325055a0; frame = (0 0; 100 100); layer = <CALayer: 0x600000c9fea0>>
        // | <UITextView: 0x134009e00; frame = (20 20; 40 40); text = ''; clipsToBounds = YES; gestureRecognizers = <NSArray: 0x600000ceaaf0>; backgroundColor = <UIDynamicSystemColor: 0x600001778100; name = systemBackgroundColor>; layer = <CALayer: 0x600000c9f630>; contentOffset: {0, 0}; contentSize: {40, 32}; adjustedContentInset: {0, 0, 0, 0}>
        // |    | <_UITextLayoutView: 0x12c506cb0; frame = (0 0; 0 0); layer = <CALayer: 0x600000cf3570>>
        // |    | <<_UITextContainerView: 0x1325078b0; frame = (0 0; 40 30); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000cde9d0>> minSize = {0, 0}, maxSize = {1.7976931348623157e+308, 1.7976931348623157e+308}, textContainer = <NSTextContainer: 0x60000352c0b0 size = (40.000000,inf); widthTracksTextView = YES; heightTracksTextView = NO>; exclusionPaths = 0x1e5cbb9d0; lineBreakMode = 0>
        // |    |    | <_UITextLayoutCanvasView: 0x132507af0; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000cde4f0>>
        // |    |    |    | <UIView: 0x132509bc0; frame = (0 0; 0 0); layer = <CALayer: 0x600000cde010>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region1 = try XCTUnwrap(result.element(at: 0))
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region1.color)
        XCTAssertEqual(region1.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region1.type, .clipBegin)
        XCTAssertEqual(region1.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.element(at: 1))
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .clipEnd)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // The text view is marked as opaque and will therefore cause a clip out of its frame
        let region3 = try XCTUnwrap(result.element(at: 2))
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region3.type, .clipOut)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 3)
    }

    func testRedact_withUITextView_withMaskAllImagesDisabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textView.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12a1052e0; frame = (0 0; 100 100); layer = <CALayer: 0x600000c1c180>>
        // | <UITextView: 0x12b00b400; frame = (20 20; 40 40); text = ''; clipsToBounds = YES; gestureRecognizers = <NSArray: 0x6000012bcf00>; backgroundColor = <UIDynamicSystemColor: 0x600001778100; name = systemBackgroundColor>; layer = <CALayer: 0x600000c1c5d0>; contentOffset: {0, 0}; contentSize: {40, 32}; adjustedContentInset: {0, 0, 0, 0}>
        // |    | <_UITextLayoutView: 0x104547bc0; frame = (0 0; 0 0); layer = <CALayer: 0x600000cddb90>>
        // |    | <<_UITextContainerView: 0x104547400; frame = (0 0; 40 30); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000cddef0>> minSize = {0, 0}, maxSize = {1.7976931348623157e+308, 1.7976931348623157e+308}, textContainer = <NSTextContainer: 0x60000350c160 size = (40.000000,inf); widthTracksTextView = YES; heightTracksTextView = NO>; exclusionPaths = 0x1e5cbb9d0; lineBreakMode = 0>
        // |    |    | <_UITextLayoutCanvasView: 0x104547840; frame = (0 0; 0 0); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000cdf8d0>>
        // |    |    |    | <UIView: 0x1047053d0; frame = (0 0; 0 0); layer = <CALayer: 0x600000d085d0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - UITextField Redaction

    func testRedact_withUITextField_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let textField = UITextField(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textField.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textField)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x104151d70; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf0ab0>>
        // | <UITextField: 0x104842200; frame = (20 20; 40 40); text = ''; opaque = NO; borderStyle = None; background = <_UITextFieldNoBackgroundProvider: 0x600000030670: textfield=<UITextField: 0x104842200>>; layer = <CALayer: 0x600000cf21f0>>
        // |    | <_UITextLayoutCanvasView: 0x104241040; frame = (0 0; 0 0); layer = <CALayer: 0x600000cee4f0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region1 = try XCTUnwrap(result.element(at: 0)) // _UITextLayoutCanvasView
                                                           // The text color of UITextView is not used for redaction
        XCTAssertNil(region1.color)
        XCTAssertEqual(region1.size, CGSize(width: 0, height: 0))
        XCTAssertEqual(region1.type, .redact)
        XCTAssertEqual(region1.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.element(at: 1)) // UITextField
                                                           // The text color of UITextView is not used for redaction
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedact_withUITextField_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let textField = UITextField(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textField.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textField)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x104151d70; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf0ab0>>
        // | <UITextField: 0x104842200; frame = (20 20; 40 40); text = ''; opaque = NO; borderStyle = None; background = <_UITextFieldNoBackgroundProvider: 0x600000030670: textfield=<UITextField: 0x104842200>>; layer = <CALayer: 0x600000cf21f0>>
        // |    | <_UITextLayoutCanvasView: 0x104241040; frame = (0 0; 0 0); layer = <CALayer: 0x600000cee4f0>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withUITextField_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let textField = UITextField(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textField.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textField)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x104151d70; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf0ab0>>
        // | <UITextField: 0x104842200; frame = (20 20; 40 40); text = ''; opaque = NO; borderStyle = None; background = <_UITextFieldNoBackgroundProvider: 0x600000030670: textfield=<UITextField: 0x104842200>>; layer = <CALayer: 0x600000cf21f0>>
        // |    | <_UITextLayoutCanvasView: 0x104241040; frame = (0 0; 0 0); layer = <CALayer: 0x600000cee4f0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - RCTTextView Redaction

    func testRedact_withRCTTextView_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10594ea10; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce53b0>>
        //   | <RCTTextView: 0x105951d60; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce6790>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withRCTTextView_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10594ea10; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce53b0>>
        //   | <RCTTextView: 0x105951d60; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce6790>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withRCTTextView_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10594ea10; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce53b0>>
        //   | <RCTTextView: 0x105951d60; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce6790>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - RCTParagraphComponentView Redaction

    func testRedact_withRCTParagraphComponent_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11a943f30; frame = (0 0; 100 100); layer = <CALayer: 0x600000cda3d0>>
        //   | <RCTParagraphComponentView: 0x106350670; frame = (20 20; 40 40); layer = <CALayer: 0x600000cdaa60>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withRCTParagraphComponent_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11a943f30; frame = (0 0; 100 100); layer = <CALayer: 0x600000cda3d0>>
        //   | <RCTParagraphComponentView: 0x106350670; frame = (20 20; 40 40); layer = <CALayer: 0x600000cdaa60>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withRCTParagraphComponent_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11a943f30; frame = (0 0; 100 100); layer = <CALayer: 0x600000cda3d0>>
        //   | <RCTParagraphComponentView: 0x106350670; frame = (20 20; 40 40); layer = <CALayer: 0x600000cdaa60>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - SwiftUI.Text Redaction

    func testRedact_withSwiftUIText_withMaskAllTextEnabled_shouldRedactView() throws {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUIText_withMaskAllTextDisabled_shouldNotRedactView() {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUIText_withMaskAllImagesDisabled_shouldRedactView() {
        XCTFail("not implemented")
    }

    // MARK: - SwiftUI.Label Redaction

    func testRedact_withSwiftUILabel_withMaskAllTextEnabled_shouldRedactView() throws {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUILabel_withMaskAllTextDisabled_shouldNotRedactView() {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUILabel_withMaskAllImagesDisabled_shouldRedactView() {
        XCTFail("not implemented")
    }

    // MARK: - SwiftUI.List Redaction

    func testRedact_withSwiftUIList_withMaskAllTextEnabled_shouldRedactView() throws {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUIList_withMaskAllTextDisabled_shouldNotRedactView() {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUIList_withMaskAllImagesDisabled_shouldRedactView() {
        XCTFail("not implemented")
    }

    // MARK: - UIImageView Redaction

    func testRedact_withUIImageView_withMaskAllImagesEnabled_shouldRedactView() throws {
        // -- Arrange --
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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withUIImageView_withMaskAllTextDisabled_shouldRedactView() {
        // -- Arrange --
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

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
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

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    // - MARK: - RCTImageView Redaction

    func testRedact_withRCTImageView_withMaskAllImagesEnabled_shouldRedactView() throws {
        // -- Arrange --
        let imageView = RCTImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10584f470; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce8fc0>>
        //   | <RCTImageView: 0x10585e6a0; frame = (20 20; 40 40); layer = <CALayer: 0x600000cea130>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withRCTImageView_withMaskAllImagesDisabled_shouldNotRedactView() {
        // -- Arrange --
        let imageView = RCTImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103667a50; frame = (0 0; 100 100); layer = <CALayer: 0x600000cdacd0>>
        //   | <RCTImageView: 0x1033537d0; frame = (20 20; 40 40); layer = <CALayer: 0x600000cec0c0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withRCTImageView_withMaskAllTextDisabled_shouldRedactView() {
        // -- Arrange --
        let imageView = RCTImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x103667a50; frame = (0 0; 100 100); layer = <CALayer: 0x600000cdacd0>>
        //   | <RCTImageView: 0x1033537d0; frame = (20 20; 40 40); layer = <CALayer: 0x600000cec0c0>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // - MARK: - SwiftUI.Image Redaction

    func testRedact_withSwiftUIImage_withMaskAllImagesEnabled_shouldRedactView() throws {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUIImage_withMaskAllImagesDisabled_shouldNotRedactView() {
        XCTFail("not implemented")
    }

    func testRedact_withSwiftUIImage_withMaskAllTextDisabled_shouldRedactView() {
        XCTFail("not implemented")
    }

    // MARK: - PDF View

    func testRedact_withPDFView_withMaskingEnabled_shouldBeRedacted() throws {
        // -- Arrange --
        let pdfView = PDFView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(pdfView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x101b98120; frame = (0 0; 100 100); layer = <CALayer: 0x600000c9f390>>
        //   | <PDFView: 0x101d256e0; frame = (20 20; 40 40); gestureRecognizers = <NSArray: 0x600000cea190>; backgroundColor = <UIDynamicSystemColor: 0x60000173f180; name = secondarySystemBackgroundColor>; layer = <CALayer: 0x600000ce80f0>>
        //   |    | <PDFScrollView: 0x104028400; baseClass = UIScrollView; frame = (0 0; 40 40); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x600000ce9d70>; layer = <CALayer: 0x600000ce8a20>; contentOffset: {0, 0}; contentSize: {0, 0}; adjustedContentInset: {0, 0, 0, 0}>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
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
        let pdfView = PDFView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(pdfView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x101b98120; frame = (0 0; 100 100); layer = <CALayer: 0x600000c9f390>>
        //   | <PDFView: 0x101d256e0; frame = (20 20; 40 40); gestureRecognizers = <NSArray: 0x600000cea190>; backgroundColor = <UIDynamicSystemColor: 0x60000173f180; name = secondarySystemBackgroundColor>; layer = <CALayer: 0x600000ce80f0>>
        //   |    | <PDFScrollView: 0x104028400; baseClass = UIScrollView; frame = (0 0; 40 40); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x600000ce9d70>; layer = <CALayer: 0x600000ce8a20>; contentOffset: {0, 0}; contentSize: {0, 0}; adjustedContentInset: {0, 0, 0, 0}>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 2)
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
    }

    // MARK: - WKWebView

    func testRedact_withWKWebView_withMaskingEnabled_shouldRedactView() throws {
        // -- Arrange --
        let webView = WKWebView(frame: .init(x: 20, y: 20, width: 40, height: 40), configuration: .init())
        rootView.addSubview(webView)

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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first) // WKWebView
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.first) // WKScrollView
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedact_withWKWebView_withMaskingDisabled_shouldRedactView() throws {
        // -- Arrange --
        let webView = WKWebView(frame: .init(x: 20, y: 20, width: 40, height: 40), configuration: .init())
        rootView.addSubview(webView)

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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40)) // WKWebView
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(result.first)
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40)) // WKScrollView
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - UIWebView

    func testRedact_withUIWebView_withMaskingEnabled_shouldRedactView() throws {
        // -- Arrange --
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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withUIWebView_withMaskingDisabled_shouldRedactView() throws {
        // -- Arrange --
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

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert no additional regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - SFSafariView Redaction

    func testRedact_withSFSafariView_withMaskingEnabled_shouldRedactViewHierarchy() throws {
#if targetEnvironment(macCatalyst)
        throw XCTSkip("SFSafariViewController opens system browser on macOS, nothing to redact, skipping test")
#else
        // -- Arrange --
        let safariViewController = SFSafariViewController(url: URL(string: "https://example.com")!)
        let safariView = try XCTUnwrap(safariViewController.view)
        safariView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(safariView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        if #available(iOS 17, *) { // iOS 17+

            // View Hierarchy:
            // ---------------
            // <UIView: 0x10294c8e0; frame = (0 0; 100 100); layer = <CALayer: 0x600000ccab50>>
            //   | <SFSafariView: 0x102b39d30; frame = (20 20; 40 40); layer = <CALayer: 0x600000cd2490>>

            let region = try XCTUnwrap(result.element(at: 0))
            XCTAssertNil(region.color)
            XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(region.type, .redact)
            XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            // Assert that there are no other regions
            XCTAssertEqual(result.count, 1)
        } else if #available(iOS 15, *) { // iOS 15 & iOS 16

            // View Hierarchy:
            // ---------------
            // <UIView: 0x12e717620; frame = (0 0; 100 100); layer = <CALayer: 0x600001a31320>>
            //    | <SFSafariView: 0x12e60ef40; frame = (20 20; 40 40); layer = <CALayer: 0x600001a5b8a0>>
            //    |    | <SFSafariLaunchPlaceholderView: 0x12e60f600; frame = (0 0; 40 40); autoresize = W+H; backgroundColor = <UIDynamicSystemColor: 0x600000f4d800; name = systemBackgroundColor>; layer = <CALayer: 0x600001a5b960>>
            //    |    |    | <UINavigationBar: 0x12e60f9a0; frame = (0 0; 0 0); opaque = NO; layer = <CALayer: 0x600001a5bc60>> delegate=0x12e60f600 no-scroll-edge-support
            //    |    |    | <UIToolbar: 0x12e7199b0; frame = (0 0; 0 0); layer = <CALayer: 0x600001a229e0>>

            let toolbarRegion = try XCTUnwrap(result.element(at: 0)) // UIToolbar
            XCTAssertNil(toolbarRegion.color)
            XCTAssertEqual(toolbarRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(toolbarRegion.type, .redact)
            XCTAssertEqual(toolbarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let navigationBarRegion = try XCTUnwrap(result.element(at: 1)) // UINavigationBar
            XCTAssertNil(navigationBarRegion.color)
            XCTAssertEqual(navigationBarRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(navigationBarRegion.type, .redact)
            XCTAssertEqual(navigationBarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let placeholderRegion = try XCTUnwrap(result.element(at: 2)) // SFSafariLaunchPlaceholderView
            XCTAssertNil(placeholderRegion.color)
            XCTAssertEqual(placeholderRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(placeholderRegion.type, .redact)
            XCTAssertEqual(toolbarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let vcRegion = try XCTUnwrap(result.element(at: 3)) // SFSafariView
            XCTAssertNil(vcRegion.color)
            XCTAssertEqual(vcRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(vcRegion.type, .redact)
            XCTAssertEqual(vcRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            // Assert that there are no other regions
            XCTAssertEqual(result.count, 4)
        } else {
            throw XCTSkip("Redaction of SFSafariViewController is not tested on iOS versions below 15")
        }
#endif
    }

    func testRedact_withSFSafariView_withMaskingDisabled_shouldRedactView() throws {
#if targetEnvironment(macCatalyst)
        throw XCTSkip("SFSafariViewController opens system browser on macOS, nothing to redact, skipping test")
#else
        // -- Arrange --
        // SFSafariView should always be redacted for security reasons,
        // regardless of maskAllText and maskAllImages settings
        let safariViewController = SFSafariViewController(url: URL(string: "https://example.com")!)
        let safariView = try XCTUnwrap(safariViewController.view)
        safariView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(safariView)

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        if #available(iOS 17, *) { // iOS 17+

            // View Hierarchy:
            // ---------------
            // <UIView: 0x10294c8e0; frame = (0 0; 100 100); layer = <CALayer: 0x600000ccab50>>
            //   | <SFSafariView: 0x102b39d30; frame = (20 20; 40 40); layer = <CALayer: 0x600000cd2490>>

            let region = try XCTUnwrap(result.element(at: 0))
            XCTAssertNil(region.color)
            XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(region.type, .redact)
            XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            // Assert that there are no other regions
            XCTAssertEqual(result.count, 1)
        } else if #available(iOS 15, *) { // iOS 15 & iOS 16

            // View Hierarchy:
            // ---------------
            // <UIView: 0x12e717620; frame = (0 0; 100 100); layer = <CALayer: 0x600001a31320>>
            //    | <SFSafariView: 0x12e60ef40; frame = (20 20; 40 40); layer = <CALayer: 0x600001a5b8a0>>
            //    |    | <SFSafariLaunchPlaceholderView: 0x12e60f600; frame = (0 0; 40 40); autoresize = W+H; backgroundColor = <UIDynamicSystemColor: 0x600000f4d800; name = systemBackgroundColor>; layer = <CALayer: 0x600001a5b960>>
            //    |    |    | <UINavigationBar: 0x12e60f9a0; frame = (0 0; 0 0); opaque = NO; layer = <CALayer: 0x600001a5bc60>> delegate=0x12e60f600 no-scroll-edge-support
            //    |    |    | <UIToolbar: 0x12e7199b0; frame = (0 0; 0 0); layer = <CALayer: 0x600001a229e0>>

            let toolbarRegion = try XCTUnwrap(result.element(at: 0)) // UIToolbar
            XCTAssertNil(toolbarRegion.color)
            XCTAssertEqual(toolbarRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(toolbarRegion.type, .redact)
            XCTAssertEqual(toolbarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let navigationBarRegion = try XCTUnwrap(result.element(at: 1)) // UINavigationBar
            XCTAssertNil(navigationBarRegion.color)
            XCTAssertEqual(navigationBarRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(navigationBarRegion.type, .redact)
            XCTAssertEqual(navigationBarRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let placeholderRegion = try XCTUnwrap(result.element(at: 2)) // SFSafariLaunchPlaceholderView
            XCTAssertNil(placeholderRegion.color)
            XCTAssertEqual(toolbarRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(placeholderRegion.type, .redact)
            XCTAssertEqual(placeholderRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            let vcRegion = try XCTUnwrap(result.element(at: 3)) // SFSafariView
            XCTAssertNil(vcRegion.color)
            XCTAssertEqual(vcRegion.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(vcRegion.type, .redact)
            XCTAssertEqual(vcRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

            // Assert that there are no other regions
            XCTAssertEqual(result.count, 4)
        } else {
            throw XCTSkip("Redaction of SFSafariViewController is not tested on iOS versions below 15")
        }
#endif
    }

    // MARK: - AVPlayer Redaction

    func testRedact_withAVPlayerViewController_shouldBeRedacted() throws {
        // -- Arrange --
        let avPlayerViewController = AVPlayerViewController()
        let avPlayerView = try XCTUnwrap(avPlayerViewController.view)
        avPlayerView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(avPlayerView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x130d0d4f0; frame = (0 0; 100 100); layer = <CALayer: 0x600003654760>>
        //    | <AVPlayerView: 0x130e27580; frame = (20 20; 40 40); autoresize = W+H; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <AVPresentationContainerViewLayer: 0x600003912400>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertGreaterThanOrEqual(result.count, 1)
        let avPlayerRegion = try XCTUnwrap(result.first)
        XCTAssertEqual(avPlayerRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(avPlayerRegion.type, .redact)
        XCTAssertEqual(avPlayerRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(avPlayerRegion.color)
    }

    func testRedact_withAVPlayerViewControllerEvenWithMaskingDisabled_shouldBeRedacted() throws {
        // -- Arrange --
        // AVPlayerViewController should always be redacted for security reasons,
        // regardless of maskAllText and maskAllImages settings
        let avPlayerViewController = AVPlayerViewController()
        let avPlayerView = try XCTUnwrap(avPlayerViewController.view)
        avPlayerView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(avPlayerView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x130d0d4f0; frame = (0 0; 100 100); layer = <CALayer: 0x600003654760>>
        //    | <AVPlayerView: 0x130e27580; frame = (20 20; 40 40); autoresize = W+H; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <AVPresentationContainerViewLayer: 0x600003912400>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertGreaterThanOrEqual(result.count, 1)
        let avPlayerRegion = try XCTUnwrap(result.first)
        XCTAssertEqual(avPlayerRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(avPlayerRegion.type, .redact)
        XCTAssertEqual(avPlayerRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(avPlayerRegion.color)
    }

    func testRedact_withAVPlayerViewInViewHierarchy_shouldBeRedacted() throws {
        // -- Arrange --
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        rootView.addSubview(view)

        let videoPlayerView = try XCTUnwrap(createFakeView(
            type: UIView.self,
            name: "AVPlayerView",
            frame: .init(x: 20, y: 20, width: 360, height: 260)
        ))
        view.addSubview(videoPlayerView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x138e18e30; frame = (0 0; 100 100); layer = <CALayer: 0x6000027850e0>>
        //    | <UIView: 0x148e359c0; frame = (0 0; 400 300); layer = <CALayer: 0x6000027d8740>>
        //    |    | <AVPlayerView: 0x148e36630; frame = (20 20; 360 260); layer = <AVPresentationContainerViewLayer: 0x6000028cd890>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let videoPlayerRegion = try XCTUnwrap(result.first)
        XCTAssertEqual(videoPlayerRegion.size, CGSize(width: 360, height: 260))
        XCTAssertEqual(videoPlayerRegion.type, .redact)
        XCTAssertEqual(videoPlayerRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(videoPlayerRegion.color)

        // Assert there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    // - MARK: - Sensitive Views

    func testRedact_withSensitiveView_shouldNotRedactHiddenView() throws {
        // -- Arrange --
        // We use any view here we know that should be redacted
        let ignoredLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 5, height: 5))
        ignoredLabel.textColor = UIColor.red
        ignoredLabel.isHidden = true
        rootView.addSubview(ignoredLabel)

        let redactedLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 8, height: 8))
        ignoredLabel.textColor = UIColor.blue
        redactedLabel.isHidden = false
        rootView.addSubview(redactedLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12be081f0; frame = (0 0; 100 100); layer = <CALayer: 0x600001161840>>
        //   | <UILabel: 0x14bd5e8b0; frame = (20 10; 5 5); hidden = YES; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600003244eb0>>
        //   | <UILabel: 0x12be0b2b0; frame = (20 20; 8 8); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x60000323ceb0>>

        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Only the redacted label will result in a region

        let region = try XCTUnwrap(result.first)
        // The text color of UITextView is not used for redaction
        XCTAssertEqual(region.color, UIColor.blue)
        XCTAssertEqual(region.size, CGSize(width: 8, height: 8))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withSensitiveView_shouldNotRedactFullyTransparentView() throws {
        // -- Arrange --
        // We use any view here we know that should be redacted
        let fullyTransparentLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 5, height: 5))
        fullyTransparentLabel.textColor = UIColor.red
        fullyTransparentLabel.alpha = 0
        rootView.addSubview(fullyTransparentLabel)

        let transparentLabel = UILabel(frame: CGRect(x: 20, y: 15, width: 3, height: 3))
        transparentLabel.textColor = UIColor.red
        transparentLabel.alpha = 0.5
        rootView.addSubview(transparentLabel)

        let nonTransparentLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 8, height: 8))
        nonTransparentLabel.alpha = 1
        rootView.addSubview(nonTransparentLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12ad2b3f0; frame = (0 0; 100 100); layer = <CALayer: 0x6000001dbca0>>
        //   | <UILabel: 0x13ad30310; frame = (20 10; 5 5); alpha = 0; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002297570>>
        //   | <UILabel: 0x12ae46a80; frame = (20 15; 3 3); alpha = 0.5; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000022fd310>>
        //   | <UILabel: 0x12ae46d80; frame = (20 20; 8 8); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000022fd3b0>>

        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Only the transparent and opaque label will result in regions, not the fully transparent one.
        let transparentLabelRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(transparentLabelRegion.color, UIColor.red)
        XCTAssertEqual(transparentLabelRegion.size, CGSize(width: 3, height: 3))
        XCTAssertEqual(transparentLabelRegion.type, .redact)
        XCTAssertEqual(transparentLabelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 15))

        let nonTransparentLabelRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(nonTransparentLabelRegion.color, UIColor.blue)
        XCTAssertEqual(nonTransparentLabelRegion.size, CGSize(width: 8, height: 8))
        XCTAssertEqual(nonTransparentLabelRegion.type, .redact)
        XCTAssertEqual(nonTransparentLabelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Clipping

    func testClipping_withOpaqueView_shouldClipOutRegion() throws {
        // -- Arrange --
        let opaqueView = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        opaqueView.backgroundColor = .white
        rootView.addSubview(opaqueView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x159613970; frame = (0 0; 100 100); layer = <CALayer: 0x6000000f34a0>>
        //    | <UIView: 0x14952d610; frame = (10 10; 60 60); backgroundColor = UIExtendedGrayColorSpace 1 1; layer = <CALayer: 0x60000009a800>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        XCTAssertEqual(region.type, .clipOut)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withLabelBehindATransparentView_shouldRedactLabel() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        let topView = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        topView.backgroundColor = .clear
        rootView.addSubview(topView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12852f900; frame = (0 0; 100 100); layer = <CALayer: 0x600002f77c60>>
        //    | <UILabel: 0x128611a50; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600000c79bd0>>
        //    | <UIView: 0x128604930; frame = (10 10; 60 60); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600002fdaf40>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 8, height: 8))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Class Ignoring

    func testAddIgnoreClasses_withSensitiveView_shouldNotRedactView() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x1186428d0; frame = (0 0; 100 100); layer = <CALayer: 0x600003954200>>
        //    | <UILabel: 0x1186445f0; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600001a75220>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        // Check that the pre-condition applies so this tests doesn't rely on other tests
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)

        sut.addIgnoreClass(UILabel.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preIgnoreResult.count, 1)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Custom Class Redaction

    func testAddRedactClasses_withCustomView_shouldRedactView() {
        // -- Arrange --
        class AnotherView: UIView {}

        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x1577208d0; frame = (0 0; 100 100); layer = <CALayer: 0x60000268b2e0>>
        //    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests52testAddRedactClasses_withCustomView_shouldRedactViewFT_T_L_11AnotherView: 0x155528e40; frame = (20 20; 40 40); layer = <CALayer: 0x6000026a3b60>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        // Check that the pre-condition applies so this tests doesn't rely on other tests
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)

        sut.addRedactClass(AnotherView.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preIgnoreResult.count, 0)
        XCTAssertEqual(result.count, 1)
    }

    func testAddRedactClass_withSubclassOfSensitiveView_shouldRedactView() throws {
        // -- Arrange --
        class AnotherView: UILabel {}

        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x14ae13230; frame = (0 0; 100 100); layer = <CALayer: 0x600000475f00>>
        //    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests63testAddRedactClass_withSubclassOfSensitiveView_shouldRedactViewFzT_T_L_11AnotherView: 0x14ae156a0; baseClass = UILabel; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002725d60>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        // The text color of UILabel subclasses is not used for redaction
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Ignore Container

    func testIgnoreContainer_withSensitiveChildView_shouldRedactView() {
        // -- Arrange --
        class IgnoreContainer: UIView {}
        class AnotherLabel: UILabel {}

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let wrappedLabel = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        ignoreContainer.addSubview(wrappedLabel)
        rootView.addSubview(ignoreContainer)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x142d4e800; frame = (0 0; 100 100); layer = <CALayer: 0x600000865080>>
        //    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests59testIgnoreContainer_withSensitiveChildView_shouldRedactViewFT_T_L_15IgnoreContainer: 0x134812870; frame = (0 0; 60 60); layer = <CALayer: 0x600000865da0>>
        //    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests59testIgnoreContainer_withSensitiveChildView_shouldRedactViewFT_T_L_12AnotherLabel: 0x1348133a0; baseClass = UILabel; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002b267b0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preIgnoreResult = sut.redactRegionsFor(view: rootView)

        sut.setIgnoreContainerClass(IgnoreContainer.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preIgnoreResult.count, 1)
        XCTAssertEqual(result.count, 0)
    }

    func testIgnoreContainer_withDirectChildView_shouldRedactView() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}
        class AnotherLabel: UILabel {}

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let wrappedLabel = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedLabel = AnotherLabel(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        wrappedLabel.addSubview(redactedLabel)
        ignoreContainer.addSubview(wrappedLabel)
        rootView.addSubview(ignoreContainer)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x133535d40; frame = (0 0; 100 100); layer = <CALayer: 0x600002ac7980>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests56testIgnoreContainer_withDirectChildView_shouldRedactViewFzT_T_L_15IgnoreContainer: 0x133616ce0; frame = (0 0; 60 60); layer = <CALayer: 0x600002a848e0>>
        //   |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests56testIgnoreContainer_withDirectChildView_shouldRedactViewFzT_T_L_12AnotherLabel: 0x133619320; baseClass = UILabel; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000009930c0>>
        //   |    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests56testIgnoreContainer_withDirectChildView_shouldRedactViewFzT_T_L_12AnotherLabel: 0x133717280; baseClass = UILabel; frame = (10 10; 10 10); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000009a9a40>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)

        sut.setIgnoreContainerClass(IgnoreContainer.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preIgnoreResult.count, 0)

        // Assert that the ignore container is redacted
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testIgnoreContainer_withIgnoreContainerAsChildOfMaskedView_shouldRedactAllViews() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}

        let redactedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedChildLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        ignoreContainer.addSubview(redactedChildLabel)
        redactedLabel.addSubview(ignoreContainer)
        rootView.addSubview(redactedLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12ef2a4f0; frame = (0 0; 100 100); layer = <CALayer: 0x600002163360>>
        //    | <UILabel: 0x12ed1c2e0; frame = (0 0; 60 60); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x60000027c910>>
        //    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests79testIgnoreContainer_withIgnoreContainerAsChildOfMaskedView_shouldRedactAllViewsFzT_T_L_15IgnoreContainer: 0x11ed31850; frame = (20 20; 40 40); layer = <CALayer: 0x6000021422a0>>
        //    |    |    | <UILabel: 0x11ed5b5a0; frame = (10 10; 10 10); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600000263cf0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)

        sut.setIgnoreContainerClass(IgnoreContainer.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preIgnoreResult.count, 0)

        // Assert that the ignore container is redacted
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that the redacted label is redacted
        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that the redacted child label is redacted
        let region3 = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(region3.type, .redact)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Redact Container

    func testRedactContainer_withChildViews_shouldRedactAllViews() throws {
        // -- Arrange --
        class RedactContainer: UIView {}
        class AnotherView: UIView {}

        let redactContainer = RedactContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedView2 = AnotherView(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        redactedView.addSubview(redactedView2)
        redactContainer.addSubview(redactedView)
        rootView.addSubview(redactContainer)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x14481dbe0; frame = (0 0; 100 100); layer = <CALayer: 0x600003e30f00>>
        //     | <_TtCFC11SentryTests26SentryUIRedactBuilderTests55testRedactContainer_withChildViews_shouldRedactAllViewsFzT_T_L_15RedactContainer: 0x1448205d0; frame = (0 0; 60 60); layer = <CALayer: 0x600003e04d80>>
        //     |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests55testRedactContainer_withChildViews_shouldRedactAllViewsFzT_T_L_11AnotherView: 0x144821040; frame = (20 20; 40 40); layer = <CALayer: 0x600003e04a80>>
        //     |    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests55testRedactContainer_withChildViews_shouldRedactAllViewsFzT_T_L_11AnotherView: 0x1448213c0; frame = (10 10; 10 10); layer = <CALayer: 0x600003e04860>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let preRedactResult = sut.redactRegionsFor(view: rootView)

        sut.setRedactContainerClass(RedactContainer.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preRedactResult.count, 0)

        // Assert that the redact container is redacted
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that the redacted view is redacted
        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that the redacted view2 is redacted
        let region3 = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(region3.type, .redact)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 3)
    }

    func testRedactContainer_withContainerAsSubviewOfSensitiveView_shouldRedactAllViews() throws {
        // -- Arrange --
        class AnotherView: UIView {}
        class RedactContainer: UIView {}

        let redactedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        redactedLabel.addSubview(redactedView)
        rootView.addSubview(redactedLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x14701dae0; frame = (0 0; 100 100); layer = <CALayer: 0x600002c07de0>>
        //    | <UILabel: 0x145d2afc0; frame = (0 0; 60 60); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600000f679d0>>
        //    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests78testRedactContainer_withContainerAsSubviewOfSensitiveView_shouldRedactAllViewsFzT_T_L_11AnotherView: 0x135d14b90; frame = (20 20; 40 40); layer = <CALayer: 0x600002cec200>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let preRedactResult = sut.redactRegionsFor(view: rootView)

        sut.setRedactContainerClass(RedactContainer.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preRedactResult.count, 0)

        // Assert that the redact container is redacted
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that the redacted view is redacted
        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedactContainerHasPriorityOverIgnoreContainer() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}
        class RedactContainer: UIView {}
        class AnotherView: UIView {}

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        let redactContainer = RedactContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let ignoreContainer2 = IgnoreContainer(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        let redactedView2 = AnotherView(frame: CGRect(x: 15, y: 15, width: 5, height: 5))
        ignoreContainer2.addSubview(redactedView2)
        redactedView.addSubview(ignoreContainer2)
        redactContainer.addSubview(redactedView)
        ignoreContainer.addSubview(redactContainer)
        rootView.addSubview(ignoreContainer)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12d62ace0; frame = (0 0; 100 100); layer = <CALayer: 0x6000002e6960>>
        //     | <_TtCFC11SentryTests26SentryUIRedactBuilderTests49testRedactContainerHasPriorityOverIgnoreContainerFzT_T_L_15IgnoreContainer: 0x12d719f00; frame = (0 0; 80 80); layer = <CALayer: 0x6000002b0460>>
        //     |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests49testRedactContainerHasPriorityOverIgnoreContainerFzT_T_L_15RedactContainer: 0x12d71a2f0; frame = (0 0; 60 60); layer = <CALayer: 0x6000002b0520>>
        //     |    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests49testRedactContainerHasPriorityOverIgnoreContainerFzT_T_L_11AnotherView: 0x12d71a670; frame = (20 20; 40 40); layer = <CALayer: 0x6000002b05c0>>
        //     |    |    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests49testRedactContainerHasPriorityOverIgnoreContainerFzT_T_L_15IgnoreContainer: 0x12d71a9f0; frame = (10 10; 10 10); layer = <CALayer: 0x6000002b05e0>>
        //     |    |    |    |    | <_TtCFC11SentryTests26SentryUIRedactBuilderTests49testRedactContainerHasPriorityOverIgnoreContainerFzT_T_L_11AnotherView: 0x12d71ab70; frame = (15 15; 5 5); layer = <CALayer: 0x6000002b0600>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        sut.setRedactContainerClass(RedactContainer.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Assert that the redact container is redacted
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that the redacted view is redacted
        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that the redacted view2 is redacted
        let region3 = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 5, height: 5))
        XCTAssertEqual(region3.type, .redact)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 15, ty: 15))

        // Assert that the redacted view2 is redacted
        let region4 = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region4.color)
        XCTAssertEqual(region4.size, CGSize(width: 5, height: 5))
        XCTAssertEqual(region4.type, .redact)
        XCTAssertEqual(region4.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 15, ty: 15))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 4)
    }

    // - MARK: - Masking / Unmasking

    func testUnmaskView_withSensitiveView_shouldNotRedactView() {
        // -- Arrange --
        class AnotherLabel: UILabel {}

        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x134633d90; frame = (0 0; 100 100); layer = <CALayer: 0x600002548a40>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests52testUnmaskView_withSensitiveView_shouldNotRedactViewFT_T_L_12AnotherLabel: 0x13460c190; baseClass = UILabel; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600000666300>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preUnmaskResult = sut.redactRegionsFor(view: rootView)
        SentrySDK.replay.unmaskView(label)
        let postUnmaskResult = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preUnmaskResult.count, 1)
        XCTAssertEqual(postUnmaskResult.count, 0)
    }

    func testMaskView_withInsensitiveView_shouldRedactView() {
        // -- Arrange --
        class AnotherView: UIView {}

        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x128f24e70; frame = (0 0; 100 100); layer = <CALayer: 0x600000d60720>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests49testMaskView_withInsensitiveView_shouldRedactViewFT_T_L_11AnotherView: 0x128f25d20; frame = (20 20; 40 40); layer = <CALayer: 0x600000d61440>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preMaskResult = sut.redactRegionsFor(view: rootView)
        SentrySDK.replay.maskView(view)
        let postMaskResult = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preMaskResult.count, 0)
        XCTAssertEqual(postMaskResult.count, 1)
    }

    func testMaskView_withSensitiveView_withViewExtension_shouldNotRedactView() {
        // -- Arrange --
        class AnotherView: UIView {}

        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x119204c10; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce70f0>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests68testMaskView_withSensitiveView_withViewExtension_shouldNotRedactViewFT_T_L_11AnotherView: 0x119205230; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce76f0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preMaskResult = sut.redactRegionsFor(view: rootView)
        view.sentryReplayMask()
        let postMaskResult = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preMaskResult.count, 0)
        XCTAssertEqual(postMaskResult.count, 1)
    }

    func testUnmaskView_withSensitiveView_withViewExtension_shouldNotRedactView() {
        // -- Arrange --
        class AnotherLabel: UILabel {}

        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105f0ba40; frame = (0 0; 100 100); layer = <CALayer: 0x600000c16d90>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests70testUnmaskView_withSensitiveView_withViewExtension_shouldNotRedactViewFT_T_L_12AnotherLabel: 0x105f0c5f0; baseClass = UILabel; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c14d80>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preUnmaskResult = sut.redactRegionsFor(view: rootView)
        label.sentryReplayUnmask()
        let postUnmaskResult = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preUnmaskResult.count, 1)
        XCTAssertEqual(postUnmaskResult.count, 0)
    }

    func testRedact_withIgnoredViewsBeforeRootSizedView_shouldNotRedactView() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)

        let overView = UIView(frame: rootView.bounds)
        overView.backgroundColor = .black
        rootView.addSubview(overView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x1056328c0; frame = (0 0; 100 100); layer = <CALayer: 0x6000010a42d0>>
        //   | <UILabel: 0x105632a60; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c58900>>
        //   | <UIView: 0x105632280; frame = (0 0; 100 100); backgroundColor = UIExtendedGrayColorSpace 0 1; layer = <CALayer: 0x6000010a4300>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withLayerIsNotFullyTransparentRedacted_shouldRedactView() throws {
        // -- Arrange --
        let view = CustomVisibilityView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.alpha = 0
        view.backgroundColor = .purple
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11cc20ab0; frame = (0 0; 100 100); layer = <CALayer: 0x600000cca340>>
        //   | <_TtCC11SentryTests26SentryUIRedactBuilderTestsP33_CFAA046DA9C91E46E31D885324D143AA20CustomVisibilityView: 0x11cc20690; frame = (20 20; 40 40); alpha = 0.5; backgroundColor = UIExtendedSRGBColorSpace 0.5 0 0.5 1; layer = <_TtCCC11SentryTests26SentryUIRedactBuilderTestsP33_CFAA046DA9C91E46E31D885324D143AA20CustomVisibilityView11CustomLayer: 0x600000cc9050>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        view.sentryReplayMask()
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 5, height: 5))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 15, ty: 15))

        // Assert that there no additional regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withViewLayerOnTopIsNotFullyTransparent_shouldRedactView() throws {
        // -- Arrange --
        let view = CustomVisibilityView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.backgroundColor = .purple
        rootView.addSubview(label)
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11cc26f80; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf56e0>>
        //   | <UILabel: 0x11cc2ac50; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c25080>>
        //   | <_TtCC11SentryTests26SentryUIRedactBuilderTestsP33_CFAA046DA9C91E46E31D885324D143AA20CustomVisibilityView: 0x11cc20f80; frame = (20 20; 40 40); alpha = 0.5; backgroundColor = UIExtendedSRGBColorSpace 0.5 0 0.5 1; layer = <_TtCCC11SentryTests26SentryUIRedactBuilderTestsP33_CFAA046DA9C91E46E31D885324D143AA20CustomVisibilityView11CustomLayer: 0x600000cf6f40>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 5, height: 5))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 15, ty: 15))

        // Assert that there no additional regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Custom View

    func testOptions_maskedViewClasses_shouldRedactCustomView() {
        // -- Arrange --
        class MyCustomView: UIView {}

        let v = MyCustomView(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
        rootView.addSubview(v)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105631ec0; frame = (0 0; 100 100); layer = <CALayer: 0x6000010a4e70>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests52testOptions_maskedViewClasses_shouldRedactCustomViewFT_T_L_12MyCustomView: 0x105631880; frame = (10 10; 30 30); layer = <CALayer: 0x6000010a40c0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true, maskedViewClasses: [MyCustomView.self])
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.size, CGSize(width: 30, height: 30))
        XCTAssertEqual(result.first?.type, .redact)
    }

    func testOptions_unmaskedViewClasses_shouldIgnoreCustomLabel() {
        // -- Arrange --
        class MyLabel: UILabel {}

        let v = MyLabel(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
        v.textColor = .purple
        rootView.addSubview(v)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105630c50; frame = (0 0; 100 100); layer = <CALayer: 0x6000010a4c00>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests55testOptions_unmaskedViewClasses_shouldIgnoreCustomLabelFT_T_L_7MyLabel: 0x10562edf0; baseClass = UILabel; frame = (10 10; 30 30); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c58880>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true, maskedViewClasses: [MyLabel.self])
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testOpaqueRotatedView_coveringRoot_doesNotClearPreviousRedactions() {
        // -- Arrange --
        // Add a label that should be redacted
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)

        // Add an opaque view that covers the root bounds but is rotated (not axis aligned)
        let cover = UIView(frame: rootView.bounds)
        cover.backgroundColor = .black
        cover.transform = CGAffineTransform(rotationAngle: .pi / 8)
        rootView.addSubview(cover)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11cc1e820; frame = (0 0; 100 100); layer = <CALayer: 0x600000cc8b70>>
        //   | <UILabel: 0x11ca06500; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c47c00>>
        //   | <UIView: 0x11ca04440; frame = (-15.3281 -15.3281; 130.656 130.656); transform = [0.92387953251128674, 0.38268343236508978, -0.38268343236508978, 0.92387953251128674, 0, 0]; backgroundColor = UIExtendedGrayColorSpace 0 1; layer = <CALayer: 0x600000c21170>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // We still expect at least one redact (for the label); the rotated cover shouldn't clear all regions
        XCTAssertTrue(result.contains(where: { $0.type == .redact && $0.size == CGSize(width: 40, height: 40) }))
    }

    func testMapRedactRegion_viewHasCustomDebugDescription_shouldUseDebugDescriptionAsName() {
        // -- Arrange --
        // We use a subclass of UILabel, so that the view is redacted by default
        class CustomDebugDescriptionLabel: UILabel {
            override var debugDescription: String {
                return "CustomDebugDescription"
            }
        }

        let view = CustomDebugDescriptionLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105d056d0; frame = (0 0; 100 100); layer = <CALayer: 0x600000c0df50>>
        //   | CustomDebugDescription

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "CustomDebugDescription")
    }

    // MARK: - Ignore SwiftUI.List background view

    func testCollectionViewListBackgroundDecorationView_isIgnoredSubtree_redactsAndDoesNotClipOut() throws {
        // -- Arrange --
        // The SwiftUI List uses an internal decoration view
        // `_UICollectionViewListLayoutSectionBackgroundColorDecorationView` which may have
        // an extremely large frame. We ensure our builder treats this as a special case and
        // redacts it directly instead of producing clip regions that could hide other masks.
        guard let decorationView = try createCollectionViewListBackgroundDecorationView(frame: .zero) else {
            throw XCTSkip("UICollectionView background decoration view is not available")
        }

        // Configure a very large frame similar to what we see in production
        decorationView.frame = CGRect(x: -20, y: -1_100, width: 440, height: 2_300)
        decorationView.backgroundColor = .systemGroupedBackground

        // Add another redacted view that must remain redacted (no clip-out should hide it)
        let titleLabel = UILabel(frame: CGRect(x: 16, y: 60, width: 120, height: 40))
        titleLabel.text = "Sample Text"

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        rootView.addSubview(decorationView)
        rootView.addSubview(titleLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x119030c20; frame = (0 0; 402 874); layer = <CALayer: 0x6000012c02a0>>
        //   | <_UICollectionViewListLayoutSectionBackgroundColorDecorationView: 0x119044de0; frame = (-20 -1100; 440 2300); backgroundColor = <UIDynamicSystemColor: 0x600001746680; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x6000012c0450>>
        //   | <UILabel: 0x11905f7c0; frame = (16 60; 120 40); text = 'Sample Text'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c2cf00>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // We should have at least two redact regions (label + decoration view)
        XCTAssertGreaterThanOrEqual(result.count, 2)
        // There must be no clipOut regions produced by the decoration view special-case
        XCTAssertFalse(result.contains(where: { $0.type == .clipOut }), "No clipOut regions expected for decoration background view")
        // Ensure we have at least one redact region that matches the large decoration view size
        XCTAssertTrue(result.contains(where: { $0.type == .redact && $0.size == decorationView.bounds.size }))
    }

    func testSwiftUIListDecorationBackground_doesNotUnmaskNavigationBarContent_elaborateHierarchy() throws {
        // -- Arrange --
        // Build a simplified but elaborate hierarchy inspired by the attached recursiveDescription.
        // The key actors are:
        // - A navigation bar label near the top that should be redacted
        // - A SwiftUI List area with a very large `_UICollectionViewListLayoutSectionBackgroundColorDecorationView`
        //   that extends well beyond the list bounds
        // This test captures the expected behavior (label remains redacted, no clipOut overshadowing),
        // but is marked as an expected failure to document the current bug.

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))

        // Navigation bar container and title label
        let navBar = UIView(frame: CGRect(x: 0, y: 56, width: 402, height: 96))
        navBar.backgroundColor = .clear
        let titleLabel = UILabel(frame: CGRect(x: 16, y: 8, width: 120, height: 40))
        titleLabel.text = "Flinky"
        navBar.addSubview(titleLabel)
        rootView.addSubview(navBar)

        // List container (mimics SwiftUI.UpdateCoalescingCollectionView)
        let listContainer = UIView(frame: CGRect(x: 0, y: 306, width: 402, height: 568))
        listContainer.clipsToBounds = true
        listContainer.backgroundColor = .systemGroupedBackground
        rootView.addSubview(listContainer)

        // Oversized decoration background view
        guard let decorationView = try createCollectionViewListBackgroundDecorationView(frame: .zero) else {
            throw XCTSkip("UICollectionView background decoration view is not available")
        }

        // Large frame similar to the debug output (-1135, 2336)
        decorationView.frame = CGRect(x: -20, y: -1_135.33, width: 442, height: 2_336)
        decorationView.backgroundColor = .systemGroupedBackground
        listContainer.addSubview(decorationView)

        // A representative list cell area (not strictly necessary for the bug but mirrors structure)
        let cell = UIView(frame: CGRect(x: 20, y: 0, width: 362, height: 45.33))
        cell.backgroundColor = .white
        listContainer.addSubview(cell)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11eb05d60; frame = (0 0; 402 874); layer = <CALayer: 0x600000ce7c30>>
        //   | <UIView: 0x11cb054f0; frame = (0 56; 402 96); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000ce7b10>>
        //   |    | <UILabel: 0x11cb04ea0; frame = (16 8; 120 40); text = 'Flinky'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c28d00>>
        //   | <UIView: 0x11cb047d0; frame = (0 306; 402 568); clipsToBounds = YES; backgroundColor = <UIDynamicSystemColor: 0x600001746680; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x600000ce64c0>>
        //   |    | <_UICollectionViewListLayoutSectionBackgroundColorDecorationView: 0x11cb04aa0; frame = (-20 -1135.33; 442 2336); backgroundColor = <UIDynamicSystemColor: 0x600001746680; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x600000ce75d0>>
        //   |    | <UIView: 0x11cb059d0; frame = (20 0; 362 45.33); backgroundColor = UIExtendedGrayColorSpace 1 1; layer = <CALayer: 0x600000ce7e10>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTExpectFailure("Decoration background may clear previous redactions due to oversized opaque frame covering root")

        // 1) Navigation title label should remain redacted (i.e., a redact region matching its size exists)
        XCTAssertTrue(result.contains(where: { $0.type == .redact && $0.size == titleLabel.bounds.size }),
                      "Navigation title label should remain redacted")

        // 2) No clipOut regions should be produced by the decoration background handling
        XCTAssertFalse(result.contains(where: { $0.type == .clipOut }),
                       "No clipOut regions expected; decoration view should not suppress unrelated masks")
    }

    // MARK: - Ignore View Subtree

    func testViewSubtreeIgnored_noIgnoredViewsInTree_shouldIncludeEntireTree() {
        // -- Arrange --
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        let subview = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        view.addSubview(subview)

        let subSubview = UIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
        subview.addSubview(subSubview)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x104609a60; frame = (0 0; 100 100); layer = <CALayer: 0x600000c13300>>
        //   | <UIView: 0x10460b850; frame = (20 20; 40 40); layer = <CALayer: 0x600000c11230>>
        //   |    | <UILabel: 0x104605340; frame = (10 10; 20 20); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c20480>>
        //   |    |    | <UIView: 0x10460c910; frame = (5 5; 10 10); layer = <CALayer: 0x600000c112c0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.element(at: 0)?.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(result.element(at: 0)?.type, .redact)
        XCTAssertEqual(result.element(at: 0)?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 35, ty: 35))
        XCTAssertNil(result.element(at: 0)?.color)

        XCTAssertEqual(result.element(at: 1)?.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(result.element(at: 1)?.type, .redact)
        XCTAssertEqual(result.element(at: 1)?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))
        XCTAssertNotNil(result.element(at: 1)?.color)

        XCTAssertEqual(result.count, 2)
    }

    func testViewSubtreeIgnored_ignoredViewsInTree_shouldIncludeEntireTree() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Type CameraUI.ChromeSwiftUIView is not available on this platform")
        }

        // -- Arrange --
        let rootView = UIView(frame: .init(origin: .zero, size: .init(width: 200, height: 200)))

        let subview = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(subview)

        // We need to ignore the subtree of the `CameraUI.ChromeSwiftUIView` class, which is an internal class of the
        // private framework `CameraUI`.
        //
        // See https://github.com/getsentry/sentry-cocoa/pull/6045 for more context.

        // Load the private framework indirectly by creating an instance of `UIImagePickerController`
        let _ = UIImagePickerController()

        // Allocate object memory without calling subclass init, because the Objective-C initializers are unavailable
        // and trapped with fatal error.
        let cameraView = try XCTUnwrap(createCameraUIView(frame: .init(x: 10, y: 10, width: 150, height: 150)))

        // Add the view to the hierarchy with additional subviews which should not be traversed even though they need
        // redaction (i.e. an UILabel).
        subview.addSubview(cameraView)

        let nestedCameraView = UILabel(frame: CGRect(x: 30, y: 30, width: 50, height: 50))
        cameraView.addSubview(nestedCameraView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x104306440; frame = (0 0; 200 200); layer = <CALayer: 0x600000cf6a90>>
        //   | <UIView: 0x10430f220; frame = (20 20; 40 40); layer = <CALayer: 0x600000cf5e60>>
        //   |    | <CameraUI.ChromeSwiftUIView: 0x104308650; frame = (10 10; 150 150); layer = <CALayer: 0x600000cf4fc0>>
        //   |    |    | <UILabel: 0x104312a90; frame = (30 30; 50 50); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c11900>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.size, CGSize(width: 150, height: 150))
        XCTAssertEqual(region.type, SentryRedactRegionType.redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))
        XCTAssertTrue(region.name.contains("CameraUI.ChromeSwiftUIView") == true)
        XCTAssertNil(region.color)

        // Assert no
        XCTAssertEqual(result.count, 1)
    }

    func testViewSubtreeIgnored_noDuplicateRedactionRegions_whenViewMeetsBothConditions() throws {
        // -- Arrange --
        // This test verifies that views meeting both general redaction criteria AND isViewSubtreeIgnored
        // condition don't create duplicate redaction regions. The ordering of checks is important -
        // isViewSubtreeIgnored must be checked first to prevent processing duplicates.

        let rootView = UIView(frame: .init(origin: .zero, size: .init(width: 200, height: 200)))

        // Create a CameraUI view that would trigger isViewSubtreeIgnored
        // The key is that this CameraUI view should only generate ONE redaction region, not two
        guard let cameraView = try createCameraUIView(frame: CGRect(x: 10, y: 10, width: 100, height: 100)) else {
            throw XCTSkip("CameraUI view is not available on this platform")
        }
        rootView.addSubview(cameraView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x102742700; frame = (0 0; 200 200); layer = <CALayer: 0x600000ce54d0>>
        //   | <CameraUI.ChromeSwiftUIView: 0x10172ec50; frame = (10 10; 100 100); layer = <CALayer: 0x600000ce8240>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Verify that exactly ONE redaction region is created for the CameraUI view,
        // proving that the deduplication fix works and we don't get duplicate regions
        XCTAssertEqual(result.count, 1, "Should have exactly one redaction region, not duplicates")
        XCTAssertEqual(result.first?.size, CGSize(width: 100, height: 100))
        XCTAssertEqual(result.first?.type, SentryRedactRegionType.redact)
        XCTAssertEqual(result.first?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))
        XCTAssertTrue(result.first?.name.contains("CameraUI.ChromeSwiftUIView") == true)
    }

    func testViewSubtreeIgnored_noDuplicatesWithCustomRedactedView() throws {
        // -- Arrange --
        // This test more explicitly demonstrates the duplicate region scenario that could occur:
        // A view hierarchy where a CameraUI view contains a UILabel that would normally be redacted.
        // The ordering of checks is important - isViewSubtreeIgnored must be checked first to prevent
        // duplicate redaction regions when views meet both conditions.

        let rootView = UIView(frame: .init(origin: .zero, size: .init(width: 200, height: 200)))

        // Create a CameraUI view that triggers isViewSubtreeIgnored
        guard let cameraView = try createCameraUIView(frame: CGRect(x: 10, y: 10, width: 100, height: 100)) else {
            throw XCTSkip("CameraUI view is not available on this platform")
        }
        rootView.addSubview(cameraView)

        // Create a view hierarchy: root -> cameraView -> label
        // The label would normally be redacted, but since it's inside a CameraUI view that triggers
        // isViewSubtreeIgnored, the entire subtree should be redacted as one region
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 60, height: 30))
        label.text = "Test Label"
        cameraView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10158f270; frame = (0 0; 200 200); layer = <CALayer: 0x600000c16b50>>
        //   | <CameraUI.ChromeSwiftUIView: 0x10158e680; frame = (10 10; 100 100); layer = <CALayer: 0x600000c169d0>>
        //   |    | <UILabel: 0x10158f410; frame = (20 20; 60 30); text = 'Test Label'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c59580>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // With the fix, we should get exactly ONE redaction region for the CameraUI view
        // The label inside should NOT create a separate redaction region because the
        // CameraUI view is handled with early return in isViewSubtreeIgnored
        XCTAssertEqual(result.count, 1, "Should have exactly one redaction region for the CameraUI view, no duplicates or separate regions for nested views")
        XCTAssertEqual(result.first?.size, CGSize(width: 100, height: 100), "Should redact the entire CameraUI view")
        XCTAssertEqual(result.first?.type, SentryRedactRegionType.redact)
        XCTAssertEqual(result.first?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))
        XCTAssertTrue(result.first?.name.contains("CameraUI.ChromeSwiftUIView") == true)
    }

    // MARK: - Helper Methods

    /// Creates an instance of ``CameraUI.ChromeSwiftUIView``
    ///
    /// - Parameter frame: The frame to set for the created view
    /// - Returns: The created CameraUI view or `nil` if the type is absent
    private func createCameraUIView(frame: CGRect) throws -> UIView? {
        // Load the private framework indirectly by creating an instance of UIImagePickerController
        let _ = UIImagePickerController()

        // Create a fake view with the type
        return try createFakeView(
            type: UIView.self,
            name: "CameraUI.ChromeSwiftUIView",
            frame: frame
        )
    }

    /// Creates an instance of ``UIKit._UICollectionViewListLayoutSectionBackgroundColorDecorationView``
    ///
    /// - Parameter frame: The frame to set for the created view
    /// - Returns: The created view or `nil` if the type is absent
    private func createCollectionViewListBackgroundDecorationView(frame: CGRect) throws -> UIView? {
        return try createFakeView(
            type: UIView.self,
            name: "_UICollectionViewListLayoutSectionBackgroundColorDecorationView",
            frame: frame
        )
    }

    /// Creates a fake instance of a view for tests.
    ///
    /// - Parameter frame: The frame to set for the created view
    /// - Returns: The created view or `nil` if the type is absent
    private func createFakeView<T: UIView>(type: T.Type, name: String, frame: CGRect) throws -> T? {
        // Obtain class at runtime – return nil if unavailable
        guard let viewClass = NSClassFromString(name) else {
            return nil
        }

        // Allocate instance without calling subclass initializers
        let instance = try XCTUnwrap(class_createInstance(viewClass, 0) as? T)

        // Reinitialize storage using UIView.initWithFrame(_:) similar to other helpers
        typealias InitWithFrame = @convention(c) (AnyObject, Selector, CGRect) -> AnyObject
        let sel = NSSelectorFromString("initWithFrame:")
        let m = try XCTUnwrap(class_getInstanceMethod(UIView.self, sel))
        let f = unsafeBitCast(method_getImplementation(m), to: InitWithFrame.self)
        _ = f(instance, sel, frame)

        return instance
    }
}

#endif // os(iOS)
