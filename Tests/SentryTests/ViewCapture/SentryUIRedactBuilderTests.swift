#if os(iOS)
import AVKit
import Foundation
import PDFKit
import SafariServices
@testable import Sentry
import SentryTestUtils
import UIKit
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

    private func getSut(maskAllText: Bool, maskAllImages: Bool) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: true,
            maskAllImages: true
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

    func testRedact_withUITextView_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textView.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textView)

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withUITextView_withMaskAllImagesDisabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textView.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textView)

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

    func testRedact_withUITextField_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let textField = UITextField(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        textField.textColor = .purple // Set a specific color so it's definitiely set
        rootView.addSubview(textField)

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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - RCTTextView Redaction

    func testRedact_withRCTTextView_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - RCTParagraphComponentView Redaction

    func testRedact_withRCTParagraphComponent_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
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

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
    }

    // - MARK: - Sensitive Views

    func testRedact_withSensitiveView_shouldNotRedactHiddenView() throws {
        // -- Arrange --
        // We use any view here we know that should be redacted
        let ignoredLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 5, height: 5))
        ignoredLabel.isHidden = true
        rootView.addSubview(ignoredLabel)

        let redactedLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 8, height: 8))
        redactedLabel.isHidden = false
        rootView.addSubview(redactedLabel)

        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Only the redacted label will result in a region

        let region = try XCTUnwrap(result.first)
        // The text color of UITextView is not used for redaction
        XCTAssertNil(region.color)
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
        fullyTransparentLabel.alpha = 0
        rootView.addSubview(fullyTransparentLabel)

        let transparentLabel = UILabel(frame: CGRect(x: 20, y: 15, width: 3, height: 3))
        transparentLabel.alpha = 0.5
        rootView.addSubview(transparentLabel)

        let nonTransparentLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 8, height: 8))
        nonTransparentLabel.alpha = 1
        rootView.addSubview(nonTransparentLabel)

        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Only the transparent and opaque label will result in regions, not the fully transparent one.

        let transparentLabelRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(transparentLabelRegion.color)
        XCTAssertEqual(transparentLabelRegion.size, CGSize(width: 3, height: 3))
        XCTAssertEqual(transparentLabelRegion.type, .redact)
        XCTAssertEqual(transparentLabelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 15))

        let nonTransparentLabelRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(nonTransparentLabelRegion.color)
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

    func testUnmaskView_withSensitiveView_shouldNotRedactView() {
        // -- Arrange --
        class AnotherLabel: UILabel {}
        
        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

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

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preUnmaskResult = sut.redactRegionsFor(view: rootView)
        label.sentryReplayUnmask()
        let postUnmaskResult = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(preUnmaskResult.count, 0)
        XCTAssertEqual(postUnmaskResult.count, 1)
    }

    func testIgnoreViewsBeforeARootSizedView() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
        let overView = UIView(frame: rootView.bounds)
        overView.backgroundColor = .black
        rootView.addSubview(overView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }
    
    func testLayerIsNotFullyTransparentRedacted() {
        // 
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let view = CustomVisibilityView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.alpha = 0
        view.sentryReplayMask()
        
        view.backgroundColor = .purple
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testViewLayerOnTopIsNotFullyTransparentRedacted() {
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let view = CustomVisibilityView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.backgroundColor = .purple
        rootView.addSubview(label)
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.first?.type, .redact)
        XCTAssertEqual(result.count, 1)
    }

    func testRedactSFSafariView() throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("SFSafariViewController opens system browser on macOS, nothing to redact, skipping test")
        #else
        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let safariViewController = SFSafariViewController(url: URL(string: "https://example.com")!)
        let safariView = try XCTUnwrap(safariViewController.view)
        safariView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(safariView)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        if #available(iOS 17, *) {
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(result.first?.type, .redact)
            XCTAssertEqual(result.first?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        } else if #available(iOS 16, *) {
            XCTAssertEqual(result.count, 4)
            XCTAssertEqual(result.element(at: 0)?.size, CGSize(width: 0, height: 0)) // UIToolbar layer
            XCTAssertEqual(result.element(at: 1)?.size, CGSize(width: 0, height: 0)) // UINavigationBar bar layer
            XCTAssertEqual(result.element(at: 2)?.size, CGSize(width: 40, height: 40)) // SFSafariLaunchPlaceholderView view
            XCTAssertEqual(result.element(at: 3)?.size, CGSize(width: 40, height: 40)) // "VC:SFSafariViewController"
        } else {
            throw XCTSkip("Redaction of SFSafariViewController is not tested on iOS versions below 16")
        }
        #endif
    }

    func testRedactSFSafariViewEvenWithMaskingDisabled() throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("SFSafariViewController opens system browser on macOS, nothing to redact, skipping test")
        #else
        // -- Arrange --
        // SFSafariView should always be redacted for security reasons, 
        // regardless of maskAllText and maskAllImages settings
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let safariViewController = SFSafariViewController(url: URL(string: "https://example.com")!)
        let safariView = try XCTUnwrap(safariViewController.view)
        safariView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(safariView)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        if #available(iOS 17, *) {
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
            XCTAssertEqual(result.first?.type, .redact)
            XCTAssertEqual(result.first?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        } else if #available(iOS 16, *) {
            // On iOS 16, SFSafariViewController has a different structure and may have multiple layers
            XCTAssertEqual(result.count, 4)
            XCTAssertEqual(result.element(at: 0)?.size, CGSize(width: 0, height: 0)) // UIToolbar layer
            XCTAssertEqual(result.element(at: 1)?.size, CGSize(width: 0, height: 0)) // UINavigationBar bar layer
            XCTAssertEqual(result.element(at: 2)?.size, CGSize(width: 40, height: 40)) // SFSafariLaunchPlaceholderView view
            XCTAssertEqual(result.element(at: 3)?.size, CGSize(width: 40, height: 40)) // "VC:SFSafariViewController"
        } else {
            throw XCTSkip("Redaction of SFSafariViewController is not tested on iOS versions below 16")
        }
        #endif
    }

    func testRedact_withPDFView_shouldBeRedacted() throws {
        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let pdfView = PDFView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(pdfView)
        
        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // Root View
        // └ PDFView            (Public API)
        //   └ PDFScrollView    (Private API)
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

    func testRedact_withPDFViewAndMaskingDisabled_shouldBeRedacted() throws {
        // -- Arrange --
        // PDFView should always be redacted for security reasons,
        // regardless of maskAllText and maskAllImages settings
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let pdfView = PDFView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(pdfView)
        
        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // Root View
        // └ PDFView            (Public API)
        //   └ PDFScrollView    (Private API)
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

//    func testPDFViewInRedactList() {
//        // -- Arrange --
//        let sut = getSut(maskAllText: true, maskAllImages: true)
//        
//        // -- Act & Assert --
//        XCTAssertTrue(sut.containsRedactClass(PDFView.self), "PDFView should be in the redact class list")
//    }
//
//    func testOptions_maskedViewClasses_shouldRedactCustomView() {
//        // -- Arrange --
//        class MyCustomView: UIView {}
//        let opts = TestRedactOptions(maskedViewClasses: [MyCustomView.self])
//        let sut = getSut(opts)
//
//        let v = MyCustomView(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
//        rootView.addSubview(v)
//
//        // -- Act --
//        let result = sut.redactRegionsFor(view: rootView)
//
//        // -- Assert --
//        XCTAssertEqual(result.count, 1)
//        XCTAssertEqual(result.first?.size, CGSize(width: 30, height: 30))
//        XCTAssertEqual(result.first?.type, .redact)
//    }
//
//    func testOptions_unmaskedViewClasses_shouldIgnoreCustomLabel() {
//        // -- Arrange --
//        class MyLabel: UILabel {}
//        let opts = TestRedactOptions(unmaskedViewClasses: [MyLabel.self])
//        let sut = getSut(opts)
//
//        let v = MyLabel(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
//        v.textColor = .purple
//        rootView.addSubview(v)
//
//        // -- Act --
//        let result = sut.redactRegionsFor(view: rootView)
//
//        // -- Assert --
//        XCTAssertEqual(result.count, 0)
//    }

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

        let sut = getSut(maskAllText: true, maskAllImages: true)

        // -- Act --
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

        let sut = getSut(maskAllText: true, maskAllImages: true)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // We still expect at least one redact (for the label); the rotated cover shouldn't clear all regions
        XCTAssertTrue(result.contains(where: { $0.type == .redact && $0.size == CGSize(width: 40, height: 40) }))
    }

    func testRedact_withAVPlayerViewController_shouldBeRedacted() throws {
        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let avPlayerViewController = AVPlayerViewController()
        let avPlayerView = try XCTUnwrap(avPlayerViewController.view)
        avPlayerView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(avPlayerView)
        
        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // Root View
        // └ AVPlayerViewController.view    (Public API)
        //   └ AVPlayerView                 (Private API)
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
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let avPlayerViewController = AVPlayerViewController()
        let avPlayerView = try XCTUnwrap(avPlayerViewController.view)
        avPlayerView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(avPlayerView)
        
        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // Root View
        // └ AVPlayerViewController.view    (Public API)
        //   └ AVPlayerView                 (Private API)
        XCTAssertGreaterThanOrEqual(result.count, 1)
        let avPlayerRegion = try XCTUnwrap(result.first)
        XCTAssertEqual(avPlayerRegion.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(avPlayerRegion.type, .redact)
        XCTAssertEqual(avPlayerRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        XCTAssertNil(avPlayerRegion.color)
    }

    func testRedact_withAVPlayerViewInViewHierarchy_shouldBeRedacted() throws {
        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let view = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        rootView.addSubview(view)

        let videoPlayerView = try XCTUnwrap(createFakeView(
            type: UIView.self,
            name: "AVPlayerView",
            frame: .init(x: 20, y: 20, width: 360, height: 260)
        ))
        view.addSubview(videoPlayerView)

        // -- Act --
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

    func testViewSubtreeIgnored_noIgnoredViewsInTree_shouldIncludeEntireTree() {
        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        let subview = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        view.addSubview(subview)

        let subSubview = UIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
        subview.addSubview(subSubview)

        // -- Act --
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
        let cameraViewClass: AnyClass
        if #available(iOS 26.0, *) {
            cameraViewClass = try XCTUnwrap(NSClassFromString("CameraUI.ChromeSwiftUIView"), "Test case expects the CameraUI.ChromeSwiftUIView class to exist")
        } else {
            throw XCTSkip("Type CameraUI.ChromeSwiftUIView is not available on this platform")
        }
        let cameraView = try XCTUnwrap(class_createInstance(cameraViewClass, 0) as? UIView)

        // Reinitialize storage using UIView.initWithFrame(_:) which can be considered instance swizzling
        //
        // This works, because we don't actually use any of the logic of the `CameraUI.ChromeSwiftUIView` and only need
        // an instance with the expected type.
        typealias InitWithFrame = @convention(c) (AnyObject, Selector, CGRect) -> AnyObject
        let sel = NSSelectorFromString("initWithFrame:")
        let m = try XCTUnwrap(class_getInstanceMethod(UIView.self, sel))
        let f = unsafeBitCast(method_getImplementation(m), to: InitWithFrame.self)
        _ = f(cameraView, sel, .zero)

        // Assert that the initialization worked but the type is still the expected one
        XCTAssertEqual(type(of: cameraView).description(), "CameraUI.ChromeSwiftUIView")

        // Add the view to the hierarchy with additional subviews which should not be traversed even though they need
        // redaction (i.e. an UILabel).
        cameraView.frame = CGRect(x: 10, y: 10, width: 150, height: 150)
        subview.addSubview(cameraView)

        let nestedCameraView = UILabel(frame: CGRect(x: 30, y: 30, width: 50, height: 50))
        cameraView.addSubview(nestedCameraView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.element(at: 0)?.size, CGSize(width: 150, height: 150))
        XCTAssertEqual(result.element(at: 0)?.type, SentryRedactRegionType.redact)
        XCTAssertEqual(result.element(at: 0)?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))
        XCTAssertTrue(result.element(at: 0)?.name.contains("CameraUI.ChromeSwiftUIView") == true)
        XCTAssertNil(result.element(at: 0)?.color)
    }

    func testMapRedactRegion_viewHasCustomDebugDescription_shouldUseDebugDescriptionAsName() {
        // -- Arrange --
        // We use a subclass of UILabel, so that the view is redacted by default
        class CustomDebugDescriptionLabel: UILabel {
            override var debugDescription: String {
                return "CustomDebugDescription"
            }
        }
        
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let view = CustomDebugDescriptionLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "CustomDebugDescription")
    }

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
        decorationView.frame = CGRect(x: -20, y: -1100, width: 440, height: 2300)
        decorationView.backgroundColor = .systemGroupedBackground

        // Add another redacted view that must remain redacted (no clip-out should hide it)
        let titleLabel = UILabel(frame: CGRect(x: 16, y: 60, width: 120, height: 40))
        titleLabel.text = "Flinky"

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        rootView.addSubview(decorationView)
        rootView.addSubview(titleLabel)

        let sut = getSut(maskAllText: true, maskAllImages: true)

        // -- Act --
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
        decorationView.frame = CGRect(x: -20, y: -1135.33, width: 442, height: 2336)
        decorationView.backgroundColor = .systemGroupedBackground
        listContainer.addSubview(decorationView)

        // A representative list cell area (not strictly necessary for the bug but mirrors structure)
        let cell = UIView(frame: CGRect(x: 20, y: 0, width: 362, height: 45.33))
        cell.backgroundColor = .white
        listContainer.addSubview(cell)

        let sut = getSut(maskAllText: true, maskAllImages: true)

        // -- Act --
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
