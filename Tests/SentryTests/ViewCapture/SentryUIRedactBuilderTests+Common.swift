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
class SentryUIRedactBuilderTests_Common: SentryUIRedactBuilderTests {
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

    // MARK: - Baseline

    func testRedact_withNoSensitiveViews_shouldNotRedactAnything() {
        // -- Arrange --
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        // Only the redacted label will result in a region
        assertSnapshot(of: masked, as: .image)

        let region = try XCTUnwrap(result.element(at: 0))
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        let region = try XCTUnwrap(result.element(at: 0))
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        let region = try XCTUnwrap(result.element(at: 0))
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        let region = try XCTUnwrap(result.element(at: 0))
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

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
        let preUnmasked = createMaskedScreenshot(view: rootView, regions: preUnmaskResult)
        SentrySDK.replay.unmaskView(label)
        let postUnmaskResult = sut.redactRegionsFor(view: rootView)
        let postUnmasked = createMaskedScreenshot(view: rootView, regions: postUnmaskResult)

        // -- Assert --
        assertSnapshot(of: preUnmasked, as: .image)
        assertSnapshot(of: postUnmasked, as: .image)

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
        let preMasked = createMaskedScreenshot(view: rootView, regions: preMaskResult)
        SentrySDK.replay.maskView(view)
        let postMaskResult = sut.redactRegionsFor(view: rootView)
        let postMasked = createMaskedScreenshot(view: rootView, regions: postMaskResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image)
        assertSnapshot(of: postMasked, as: .image)

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
        let preMasked = createMaskedScreenshot(view: rootView, regions: preMaskResult)
        view.sentryReplayMask()
        let postMaskResult = sut.redactRegionsFor(view: rootView)
        let postMasked = createMaskedScreenshot(view: rootView, regions: postMaskResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image)
        assertSnapshot(of: postMasked, as: .image)

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
        let preUnmasked = createMaskedScreenshot(view: rootView, regions: preUnmaskResult)
        label.sentryReplayUnmask()
        let postUnmaskResult = sut.redactRegionsFor(view: rootView)
        let postUnmasked = createMaskedScreenshot(view: rootView, regions: postUnmaskResult)

        // -- Assert --
        assertSnapshot(of: preUnmasked, as: .image)
        assertSnapshot(of: postUnmasked, as: .image)

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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.element(at: 0)?.size, CGSize(width: 30, height: 30))
        XCTAssertEqual(result.element(at: 0)?.type, .redact)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.element(at: 0)?.name, "CustomDebugDescription")
    }

    // MARK: - API surface: addIgnoreClasses / addRedactClasses

    func testAddIgnoreClasses_arrayAPI_shouldNotRedactViews() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
        label.textColor = .purple
        let textField = UITextField(frame: CGRect(x: 50, y: 10, width: 30, height: 30))
        rootView.addSubview(label)
        rootView.addSubview(textField)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        // Pre-condition: both would be redacted
        let pre = sut.redactRegionsFor(view: rootView)
        XCTAssertGreaterThanOrEqual(pre.count, 1)

        sut.addIgnoreClasses([UILabel.self, UITextField.self])
        let post = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: post)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(post.count, 0)
    }

    func testAddRedactClasses_arrayAPI_shouldRedactCustomViews() {
        // -- Arrange --
        class V1: UIView {}
        class V2: UIView {}
        let v1 = V1(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        let v2 = V2(frame: CGRect(x: 40, y: 10, width: 20, height: 20))
        rootView.addSubview(v1)
        rootView.addSubview(v2)

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)

        let pre = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(pre.count, 0)

        sut.addRedactClasses([V1.self, V2.self])
        let post = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: post)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        XCTAssertEqual(post.count, 2)
        XCTAssertTrue(post.contains(where: { $0.size == CGSize(width: 20, height: 20) && $0.transform.tx == 10 && $0.transform.ty == 10 }))
        XCTAssertTrue(post.contains(where: { $0.size == CGSize(width: 20, height: 20) && $0.transform.tx == 40 && $0.transform.ty == 10 }))
    }

    // MARK: - Default ignored controls

    func testDefaultIgnoredControls_shouldNotRedactUISliderAndUISwitch() {
        // -- Arrange --
        let slider = UISlider(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        let toggle = UISwitch(frame: CGRect(x: 10, y: 40, width: 50, height: 30))
        rootView.addSubview(slider)
        rootView.addSubview(toggle)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Force redaction propagation (non-clipping redacted parent)

    func testForceRedact_propagatesToChildren_whenParentMarkedAndNotClipping() {
        // -- Arrange --
        class Container: UIView {}
        class Child: UIView {}
        let container = Container(frame: CGRect(x: 10, y: 10, width: 80, height: 60))
        container.clipsToBounds = false
        let child = Child(frame: CGRect(x: 5, y: 5, width: 20, height: 20))
        container.addSubview(child)
        rootView.addSubview(container)

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        // Mark the container view instance to be force masked
        SentrySDK.replay.maskView(container)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        // Expect two redact regions: one for container, one for child due to enforceRedact
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(where: { $0.size == CGSize(width: 80, height: 60) && $0.transform.tx == 10 && $0.transform.ty == 10 }))
        XCTAssertTrue(result.contains(where: { $0.size == CGSize(width: 20, height: 20) && $0.transform.tx == 15 && $0.transform.ty == 15 }))
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
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

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
}

#endif // os(iOS)
