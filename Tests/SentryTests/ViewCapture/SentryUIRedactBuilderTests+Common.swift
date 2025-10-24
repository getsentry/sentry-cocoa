// swiftlint:disable file_length
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
class SentryUIRedactBuilderTests_Common: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name
    private func getSut(maskAllText: Bool, maskAllImages: Bool, maskedViewClasses: [AnyClass] = [], unmaskedViewClasses: [AnyClass] = []) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            maskedViewClasses: maskedViewClasses,
            unmaskedViewClasses: unmaskedViewClasses
        ))
    }

    // MARK: - Baseline

    func testRedact_withNoSensitiveViews_shouldNotRedactAnything() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    // - MARK: - Visibility & Opacity (layer.isHidden and layer.opacity)

    func testRedact_withHiddenSensitiveView_shouldNotRedactView() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        // Tests that views with isHidden=true are skipped in mapRedactRegion
        // (early return when layer.isHidden == true)
        let ignoredLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 40, height: 5))
        ignoredLabel.textColor = UIColor.red
        ignoredLabel.isHidden = true
        ignoredLabel.text = "Ignored"
        rootView.addSubview(ignoredLabel)

        let redactedLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 50, height: 8))
        redactedLabel.textColor = UIColor.blue
        redactedLabel.isHidden = false
        redactedLabel.text = "Redacted"
        rootView.addSubview(redactedLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12be081f0; frame = (0 0; 100 100); layer = <CALayer: 0x600001161840>>
        //   | <UILabel: 0x14bd5e8b0; frame = (20 10; 40 5); hidden = YES; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600003244eb0>>
        //   | <UILabel: 0x12be0b2b0; frame = (20 20; 50 8); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x60000323ceb0>>

        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        // The text color of UITextView is not used for redaction
        XCTAssertEqual(region.color, UIColor.blue)
        XCTAssertEqual(region.size, CGSize(width: 50, height: 8))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withSensitiveView_shouldNotRedactFullyTransparentView() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        // Tests that views with layer.opacity=0 are skipped in mapRedactRegion
        // (early return when layer.opacity == 0)
        // Also tests that partially transparent views (0 < opacity < 1) ARE still redacted
        let fullyTransparentLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 45, height: 5))
        fullyTransparentLabel.text = "FTL"
        fullyTransparentLabel.textColor = UIColor.red
        fullyTransparentLabel.alpha = 0 // opacity == 0: should NOT be redacted
        rootView.addSubview(fullyTransparentLabel)

        let transparentLabel = UILabel(frame: CGRect(x: 20, y: 15, width: 43, height: 3))
        transparentLabel.text = "TL"
        transparentLabel.textColor = UIColor.green
        transparentLabel.alpha = 0.5 // 0 < opacity < 1: SHOULD be redacted
        rootView.addSubview(transparentLabel)

        let nonTransparentLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 48, height: 8))
        nonTransparentLabel.text = "NTL"
        nonTransparentLabel.textColor = UIColor.purple
        nonTransparentLabel.alpha = 1 // opacity == 1: SHOULD be redacted
        rootView.addSubview(nonTransparentLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12ad2b3f0; frame = (0 0; 100 100); layer = <CALayer: 0x6000001dbca0>>
        //   | <UILabel: 0x13ad30310; frame = (20 10; 45 5); alpha = 0; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002297570>>
        //   | <UILabel: 0x12ae46a80; frame = (20 15; 43 3); alpha = 0.5; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000022fd310>>
        //   | <UILabel: 0x12ae46d80; frame = (20 20; 48 8); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000022fd3b0>>

        // -- Arrange --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Only the transparent and opaque label will result in regions, not the fully transparent one.
        let nonTransparentLabelRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(nonTransparentLabelRegion.color, UIColor.purple)
        XCTAssertEqual(nonTransparentLabelRegion.size, CGSize(width: 48, height: 8))
        XCTAssertEqual(nonTransparentLabelRegion.type, .redact)
        XCTAssertEqual(nonTransparentLabelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let transparentLabelRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(transparentLabelRegion.color, UIColor.green)
        XCTAssertEqual(transparentLabelRegion.size, CGSize(width: 43, height: 3))
        XCTAssertEqual(transparentLabelRegion.type, .redact)
        XCTAssertEqual(transparentLabelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 15))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Clipping

    func testClipping_withOpaqueView_shouldClipOutRegion() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

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
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello, World!"
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
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        // The text color of UITextView is not used for redaction
        XCTAssertEqual(region.color, label.textColor.withAlphaComponent(1.0))
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Class Ignoring

    func testAddIgnoreClasses_withSensitiveView_shouldNotRedactView() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello, World!"
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x1186428d0; frame = (0 0; 100 100); layer = <CALayer: 0x600003954200>>
        //    | <UILabel: 0x1186445f0; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600001a75220>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        // Check that the pre-condition applies so this tests doesn't rely on other tests
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)
        let preIgnored = createMaskedScreenshot(view: rootView, regions: preIgnoreResult)

        sut.addIgnoreClass(UILabel.self)

        let postIgnoreResult = sut.redactRegionsFor(view: rootView)
        let postIgnored = createMaskedScreenshot(view: rootView, regions: postIgnoreResult)

        // -- Assert --
        assertSnapshot(of: preIgnored, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        XCTAssertEqual(preIgnoreResult.count, 1)

        assertSnapshot(of: postIgnored, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        XCTAssertEqual(postIgnoreResult.count, 0)
    }

    // MARK: - Custom Class Redaction

    func testAddRedactClasses_withCustomView_shouldRedactView() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = TestGridView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x1577208d0; frame = (0 0; 100 100); layer = <CALayer: 0x60000268b2e0>>
        //    | <_TtC11SentryTestsP33_DDB6F43D9D557573114568C470CB24C611AnotherView: 0x155528e40; frame = (20 20; 40 40); layer = <CALayer: 0x6000026a3b60>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        // Check that the pre-condition applies so this tests doesn't rely on other tests
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preIgnoreResult)

        sut.addRedactClass(TestGridView.self)

        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        XCTAssertEqual(preIgnoreResult.count, 0)

        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        XCTAssertEqual(result.count, 1)
    }

    func testAddRedactClass_withSubclassOfSensitiveView_shouldRedactView() throws {
        // -- Arrange --
        class AnotherView: UILabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.text = "Hello, World!"
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
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        // The text color of UILabel subclasses is not used for redaction
        XCTAssertEqual(region.color, UIColor.label.withAlphaComponent(1.0))
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testContainsRedactClass_withMultipleInheritanceLevels_shouldMatch() throws {
        // -- Arrange --
        class CustomLabel: UILabel {}
        class VeryCustomLabel: CustomLabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let label = VeryCustomLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello"
        label.textColor = UIColor.green
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        // Should match because UILabel is in the redact list, even through multiple inheritance levels
        assertSnapshot(of: rootView, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        let region = try XCTUnwrap(result.element(at: 0))
        // The text color of UILabel subclasses is not used for redaction
        XCTAssertEqual(region.color, UIColor.green)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Ignore Container

    func testIgnoreContainer_withSensitiveChildView_shouldNotRedactView() {
        // -- Arrange --
        class IgnoreContainer: UIView {}
        class AnotherLabel: UILabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let wrappedLabel = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        wrappedLabel.text = "Hello, World!"
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
        let preIgnore = createMaskedScreenshot(view: rootView, regions: preIgnoreResult)

        sut.setIgnoreContainerClass(IgnoreContainer.self)

        let postIgnoreResult = sut.redactRegionsFor(view: rootView)
        let postIgnore = createMaskedScreenshot(view: rootView, regions: postIgnoreResult)

        // -- Assert --
        assertSnapshot(of: preIgnore, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        XCTAssertEqual(preIgnoreResult.count, 1)

        assertSnapshot(of: postIgnore, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        XCTAssertEqual(postIgnoreResult.count, 0)
    }

    func testIgnoreContainer_withDirectChildView_shouldRedactView() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}
        class AnotherLabel: UILabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let wrappedLabel = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        wrappedLabel.text = "WL"
        let redactedLabel = AnotherLabel(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        redactedLabel.text = "RL"
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
        let preIgnored = createMaskedScreenshot(view: rootView, regions: preIgnoreResult)

        sut.setIgnoreContainerClass(IgnoreContainer.self)

        let postIgnoreResult = sut.redactRegionsFor(view: rootView)
        let postIgnored = createMaskedScreenshot(view: rootView, regions: postIgnoreResult)

        // -- Assert --
        assertSnapshot(of: preIgnored, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        XCTAssertEqual(preIgnoreResult.count, 2)

        // Assert that the ignore container is redacted
        assertSnapshot(of: postIgnored, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        let region = try XCTUnwrap(postIgnoreResult.element(at: 0))
        XCTAssertEqual(region.color, redactedLabel.textColor.withAlphaComponent(1.0))
        XCTAssertEqual(region.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))

        // Assert that there are no other regions
        XCTAssertEqual(postIgnoreResult.count, 1)
    }

    func testIgnoreContainer_withIgnoreContainerAsChildOfMaskedView_shouldRedactAllViews() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let redactedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        redactedLabel.text = "RL"
        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedChildLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        redactedChildLabel.text = "RCL"
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
        let preIgnored = createMaskedScreenshot(view: rootView, regions: preIgnoreResult)

        sut.setIgnoreContainerClass(IgnoreContainer.self)

        let postIgnoreResult = sut.redactRegionsFor(view: rootView)
        let postIgnored = createMaskedScreenshot(view: rootView, regions: postIgnoreResult)

        // -- Assert --
        assertSnapshot(of: preIgnored, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Assert that the ignore container is redacted
        let region = try XCTUnwrap(preIgnoreResult.element(at: 0))
        XCTAssertEqual(region.color, redactedChildLabel.textColor.withAlphaComponent(1.0))
        XCTAssertEqual(region.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))

        // Assert that the redacted label is redacted
        let region2 = try XCTUnwrap(preIgnoreResult.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that the redacted child label is redacted
        let region3 = try XCTUnwrap(preIgnoreResult.element(at: 2))
        XCTAssertEqual(region.color, redactedLabel.textColor.withAlphaComponent(1.0))
        XCTAssertEqual(region3.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region3.type, .redact)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that there are no other regions
        XCTAssertEqual(preIgnoreResult.count, 3)

        // We expect the redact regions to be unchanged
        assertSnapshot(of: postIgnored, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        XCTAssertEqual(postIgnoreResult, preIgnoreResult)
    }

    // MARK: - Redact Container

    func testRedactContainer_withChildViews_shouldRedactAllViews() throws {
        // -- Arrange --
        class RedactContainer: UIView {}
        class AnotherView: UIView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
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
        let preRedactMasked = createMaskedScreenshot(view: rootView, regions: preRedactResult)

        sut.setRedactContainerClass(RedactContainer.self)

        let postRedactResult = sut.redactRegionsFor(view: rootView)
        let postRedactMasked = createMaskedScreenshot(view: rootView, regions: postRedactResult)

        // -- Assert --
        assertSnapshot(of: preRedactMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: postRedactMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Assert pre-condition: no redactions before setting container
        XCTAssertEqual(preRedactResult.count, 0)

        // Assert that the redacted child label is redacted
        let region = try XCTUnwrap(postRedactResult.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))

        // Assert that the ignore container is redacted
        let region2 = try XCTUnwrap(postRedactResult.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that the redacted label is redacted
        let region3 = try XCTUnwrap(postRedactResult.element(at: 2))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region3.type, .redact)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that there are no other regions
        XCTAssertEqual(postRedactResult.count, 3)
    }

    func testRedactContainer_withContainerAsSubviewOfSensitiveView_shouldRedactAllViews() throws {
        // -- Arrange --
        class AnotherView: UIView {}
        class RedactContainer: UIView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let redactedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        redactedLabel.text = "RL"
        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        redactedView.backgroundColor = UIColor.red.withAlphaComponent(0.5) // Use a non-opaque color so it doesn't clip
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
        let preMasked = createMaskedScreenshot(view: rootView, regions: preRedactResult)

        sut.setRedactContainerClass(RedactContainer.self)

        let postRedactResult = sut.redactRegionsFor(view: rootView)
        let postRedactMasked = createMaskedScreenshot(view: rootView, regions: postRedactResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        // Assert that the pre-redact container had redactions
        let region = try XCTUnwrap(preRedactResult.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        let region2 = try XCTUnwrap(preRedactResult.element(at: 1))
        XCTAssertEqual(region2.color, redactedLabel.textColor.withAlphaComponent(1.0))
        XCTAssertEqual(region2.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that there are no other regions
        XCTAssertEqual(preRedactResult.count, 2)

        // Assert that the redact regions did not change after setting redact container
        assertSnapshot(of: postRedactMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        XCTAssertEqual(postRedactResult, preRedactResult)
    }

    func testRedactContainer_shouldHavePriorityOverIgnoreContainer() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}
        class RedactContainer: UIView {}
        class AnotherView: UIView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        ignoreContainer.backgroundColor = UIColor.red.withAlphaComponent(0.9) // Use a non-opaque color to remove clipping

        let redactContainer = RedactContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        redactContainer.backgroundColor = UIColor.green.withAlphaComponent(0.9) // Use a non-opaque color to remove clipping
        redactContainer.isOpaque = false

        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        redactedView.backgroundColor = UIColor.blue.withAlphaComponent(0.9) // Use a non-opaque color to remove clipping
        redactedView.isOpaque = false

        let ignoreContainer2 = IgnoreContainer(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        ignoreContainer2.backgroundColor = UIColor.orange.withAlphaComponent(0.9) // Use a non-opaque color to remove clipping
        ignoreContainer2.isOpaque = false

        let redactedView2 = AnotherView(frame: CGRect(x: 15, y: 15, width: 5, height: 5))
        redactedView2.backgroundColor = UIColor.cyan.withAlphaComponent(0.9) // Use a non-opaque color to remove clipping
        redactedView2.isOpaque = false

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
        let preRedactResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preRedactResult)

        sut.setRedactContainerClass(RedactContainer.self)

        let postRedactResult = sut.redactRegionsFor(view: rootView)
        let postRedactMasked = createMaskedScreenshot(view: rootView, regions: postRedactResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: postRedactMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Assert pre-condition: no redactions before setting container
        XCTAssertEqual(preRedactResult.count, 0)

        // Assert that the redact container is redacted
        let region = try XCTUnwrap(postRedactResult.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 5, height: 5))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 45, ty: 45))

        // Assert that the redacted view is redacted
        let region2 = try XCTUnwrap(postRedactResult.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))

        // Assert that the redacted view2 is redacted
        let region3 = try XCTUnwrap(postRedactResult.element(at: 2))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region3.type, .redact)
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that the redacted view3 is redacted
        let region4 = try XCTUnwrap(postRedactResult.element(at: 3))
        XCTAssertNil(region4.color)
        XCTAssertEqual(region4.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region4.type, .redact)
        XCTAssertEqual(region4.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))

        // Assert that there are no other regions
        XCTAssertEqual(postRedactResult.count, 4)
    }

    // - MARK: - Masking Views

    func testMaskView_withInsensitiveView_shouldRedactView() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = TestGridView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x128f24e70; frame = (0 0; 100 100); layer = <CALayer: 0x600000d60720>>
        //   | <_TtC11SentryTestsP33_DDB6F43D9D557573114568C470CB24C612TestGridView: 0x128f25d20; frame = (20 20; 40 40); layer = <CALayer: 0x600000d61440>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preMaskResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preMaskResult)

        SentrySDK.replay.maskView(view)

        let postMaskResult = sut.redactRegionsFor(view: rootView)
        let postMasked = createMaskedScreenshot(view: rootView, regions: postMaskResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: postMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Assert pre-condition: view not masked by default
        XCTAssertEqual(preMaskResult.count, 0)

        // Assert post-condition: view is now masked
        XCTAssertEqual(postMaskResult.count, 1)
    }

    func testMaskView_withInsensitiveView_withViewExtension_shouldNotRedactView() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = TestGridView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x119204c10; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce70f0>>
        //   | <_TtC11SentryTestsP33_DDB6F43D9D557573114568C470CB24C612TestGridView: 0x119205230; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce76f0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preMaskResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preMaskResult)

        view.sentryReplayMask()

        let postMaskResult = sut.redactRegionsFor(view: rootView)
        let postMasked = createMaskedScreenshot(view: rootView, regions: postMaskResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: postMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Assert pre-condition: view not masked by default
        XCTAssertEqual(preMaskResult.count, 0)

        // Assert post-condition: view is now masked
        XCTAssertEqual(postMaskResult.count, 1)
    }

    func testForceRedact_propagatesToChildren_whenParentMarkedAndNotClipping() throws {
        // -- Arrange --
        class Container: UIView {}
        class Child: UIView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let container = Container(frame: CGRect(x: 10, y: 10, width: 80, height: 60))
        container.clipsToBounds = false
        rootView.addSubview(container)

        let child = Child(frame: CGRect(x: 5, y: 5, width: 20, height: 20))
        container.addSubview(child)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x12161bdf0; frame = (0 0; 100 100); layer = <CALayer: 0x600003f18dc0>>
        //   | <_TtCFC11SentryTests33SentryUIRedactBuilderTests_Common67testForceRedact_propagatesToChildren_whenParentMarkedAndNotClippingFT_T_L_9Container: 0x12161c990; frame = (10 10; 80 60); layer = <CALayer: 0x600003f19ae0>>
        //   |    | <_TtCFC11SentryTests33SentryUIRedactBuilderTests_Common67testForceRedact_propagatesToChildren_whenParentMarkedAndNotClippingFT_T_L_5Child: 0x12161de50; frame = (5 5; 20 20); layer = <CALayer: 0x600003f19ba0>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let preResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preResult)

        SentrySDK.replay.maskView(container)

        let postMaskResult = sut.redactRegionsFor(view: rootView)
        let postMasked = createMaskedScreenshot(view: rootView, regions: postMaskResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))
        assertSnapshot(of: postMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))

        // Assert pre-condition: no redactions before masking container
        XCTAssertEqual(preResult.count, 0)

        // Expect two redact regions: one for container, one for child due to enforceRedact
        let region = try XCTUnwrap(postMaskResult.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 15, ty: 15))

        let region2 = try XCTUnwrap(postMaskResult.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 80, height: 60))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // Assert that there are no other regions
        XCTAssertEqual(postMaskResult.count, 2)
    }

    // MARK: - Unmasking Views

    func testUnmaskView_withSensitiveView_shouldNotRedactView() {
        // -- Arrange --
        class AnotherLabel: UILabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 80, height: 40))
        label.text = "Hello World"
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x15c50ff70; frame = (0 0; 100 100); layer = <CALayer: 0x6000005c54e0>>
        //   | <_TtCFC11SentryTests33SentryUIRedactBuilderTests_Common52testUnmaskView_withSensitiveView_shouldNotRedactViewFT_T_L_12AnotherLabel: 0x14c7321a0; baseClass = UILabel; frame = (20 20; 80 40); text = 'Hello World'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x6000026ea170>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        let preUnmaskResult = sut.redactRegionsFor(view: rootView)
        let preUnmasked = createMaskedScreenshot(view: rootView, regions: preUnmaskResult)

        SentrySDK.replay.unmaskView(label)

        let postUnmaskResult = sut.redactRegionsFor(view: rootView)
        let postUnmasked = createMaskedScreenshot(view: rootView, regions: postUnmaskResult)

        // -- Assert --
        assertSnapshot(of: preUnmasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        assertSnapshot(of: postUnmasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        // Assert pre-condition: label is masked by default
        XCTAssertEqual(preUnmaskResult.count, 1)

        // Assert post-condition: label is now unmasked
        XCTAssertEqual(postUnmaskResult.count, 0)
    }

    func testUnmaskView_withSensitiveView_withViewExtension_shouldNotRedactView() {
        // -- Arrange --
        class AnotherLabel: UILabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello World"
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
        assertSnapshot(of: preUnmasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        assertSnapshot(of: postUnmasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        // Assert pre-condition: label is masked by default
        XCTAssertEqual(preUnmaskResult.count, 1)

        // Assert post-condition: label is now unmasked
        XCTAssertEqual(postUnmaskResult.count, 0)
    }

    // MARK: - Other Masking

    func testRedact_withIgnoredViewsBeforeRootSizedView_shouldNotRedactView() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello World"
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

    func testRedact_withViewLayerOnTopIsNotFullyTransparent_shouldRedactView() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = TestCustomVisibilityView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello World"
        view.backgroundColor = .purple
        rootView.addSubview(label)
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11cc26f80; frame = (0 0; 100 100); layer = <CALayer: 0x600000cf56e0>>
        //   | <UILabel: 0x11cc2ac50; frame = (20 20; 40 40); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c25080>>
        //   | <_TtC11SentryTestsP33_DDB6F43D9D557573114568C470CB24C624TestCustomVisibilityView: 0x11cc20f80; frame = (20 20; 40 40); alpha = 0.5; backgroundColor = UIExtendedSRGBColorSpace 0.5 0 0.5 1; layer = <_TtCC11SentryTestsP33_DDB6F43D9D557573114568C470CB24C624TestCustomVisibilityView11CustomLayer: 0x600000cf6f40>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.color, label.textColor.withAlphaComponent(1.0))
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that there no additional regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Custom View

    func testOptions_maskedViewClasses_shouldRedactCustomView() throws {
        // -- Arrange --
        class MyCustomView: UIView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = MyCustomView(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
        rootView.addSubview(view)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105631ec0; frame = (0 0; 100 100); layer = <CALayer: 0x6000010a4e70>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests52testOptions_maskedViewClasses_shouldRedactCustomViewFT_T_L_12MyCustomView: 0x105631880; frame = (10 10; 30 30); layer = <CALayer: 0x6000010a40c0>>

        // -- Act --
        let baseSut = getSut(maskAllText: true, maskAllImages: true, maskedViewClasses: [])
        let baseResult = baseSut.redactRegionsFor(view: rootView)
        let baseMasked = createMaskedScreenshot(view: rootView, regions: baseResult)

        let sut = getSut(maskAllText: true, maskAllImages: true, maskedViewClasses: [MyCustomView.self])
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: baseMasked, as: .image)
        XCTAssertEqual(baseResult.count, 0)

        assertSnapshot(of: masked, as: .image)
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 30, height: 30))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testOptions_unmaskedViewClasses_shouldIgnoreCustomLabel() {
        // -- Arrange --
        class MyLabel: UILabel {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = MyLabel(frame: CGRect(x: 10, y: 10, width: 80, height: 30))
        label.text = "Hello World"
        label.textColor = .purple
        rootView.addSubview(label)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x105630c50; frame = (0 0; 100 100); layer = <CALayer: 0x6000010a4c00>>
        //   | <_TtCFC11SentryTests26SentryUIRedactBuilderTests55testOptions_unmaskedViewClasses_shouldIgnoreCustomLabelFT_T_L_7MyLabel: 0x10562edf0; baseClass = UILabel; frame = (10 10; 30 30); userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c58880>>

        // -- Act --
        let baseSut = getSut(maskAllText: true, maskAllImages: true, unmaskedViewClasses: [])
        let baseResult = baseSut.redactRegionsFor(view: rootView)
        let baseMasked = createMaskedScreenshot(view: rootView, regions: baseResult)

        let sut = getSut(maskAllText: true, maskAllImages: true, unmaskedViewClasses: [MyLabel.self])
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: baseMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        // Assert pre-condition: label is masked without unmask classes
        XCTAssertEqual(baseResult.count, 1)

        // Assert post-condition: label is unmasked with unmask classes
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Utilities

    func testMapRedactRegion_viewHasCustomDebugDescription_shouldUseDebugDescriptionAsName() throws {
        // -- Arrange --
        // We use a subclass of UILabel, so that the view is redacted by default
        class CustomDebugDescriptionLabel: UILabel {
            override var debugDescription: String {
                return "CustomDebugDescription"
            }
        }

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
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
        // No snapshot assertion here, because there's no value.
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.name, "CustomDebugDescription")

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - API surface: addIgnoreClasses / addRedactClasses

    func testAddIgnoreClasses_arrayAPI_shouldNotRedactViews() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
        label.text = "Hello World"
        label.textColor = .purple
        label.font = .systemFont(ofSize: 20)
        rootView.addSubview(label)

        let textField = UITextField(frame: CGRect(x: 50, y: 10, width: 30, height: 30))
        textField.placeholder = "Edit Me"
        rootView.addSubview(textField)

        // View Hierarchy:
        // ---------------
        // == iOS 26 & 18 & 17 & 16 ==
        // <UIView: 0x106242b00; frame = (0 0; 100 100); layer = <CALayer: 0x600000cdad60>>
        //   | <UILabel: 0x101c39bc0; frame = (10 10; 30 30); text = 'Hello World'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c31400>>
        //   | <UITextField: 0x102024000; frame = (50 10; 30 30); text = ''; opaque = NO; placeholder = Edit Me; borderStyle = None; background = <_UITextFieldNoBackgroundProvider: 0x60000002a0a0: textfield=<UITextField: 0x102024000>>; layer = <CALayer: 0x600000ce6520>>
        //   |    | <UITextFieldLabel: 0x106244d10; frame = (0 5; 30 20.3333); text = 'Edit Me'; opaque = NO; userInteractionEnabled = NO; layer = <_UILabelLayer: 0x600002c26880>>
        //   |    | <_UITextLayoutCanvasView: 0x101c04a00; frame = (0 0; 30 30); layer = <CALayer: 0x600000ce8e40>>
        //   |    |    | <_UITextLayoutFragmentView: 0x10624d4a0; frame = (0 5; 0 21); opaque = NO; layer = <CALayer: 0x600000ce5800>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)

        // Pre-condition: both would be redacted
        let preResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preResult)

        sut.addIgnoreClasses([UILabel.self, UITextField.self])

        let postResult = sut.redactRegionsFor(view: rootView)
        let postMasked = createMaskedScreenshot(view: rootView, regions: postResult)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "masked"))
        assertSnapshot(of: postMasked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        let canvasRegion = try XCTUnwrap(preResult.element(at: 0))
        XCTAssertEqual(canvasRegion.size, .zero)
        XCTAssertEqual(canvasRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 50, ty: 10))
        XCTAssertEqual(canvasRegion.type, .redact)
        XCTAssertNil(canvasRegion.color)

        let textFieldRegion = try XCTUnwrap(preResult.element(at: 1))
        XCTAssertEqual(textFieldRegion.size, CGSize(width: 30, height: 30))
        XCTAssertEqual(textFieldRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 50, ty: 10))
        XCTAssertEqual(textFieldRegion.type, .redact)
        XCTAssertNil(textFieldRegion.color)

        let labelRegion = try XCTUnwrap(preResult.element(at: 2))
        XCTAssertEqual(labelRegion.size, CGSize(width: 30, height: 30))
        XCTAssertEqual(labelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))
        XCTAssertEqual(labelRegion.type, .redact)
        XCTAssertEqual(labelRegion.color, UIColor.purple)

        // Assert that there are no other regions
        XCTAssertEqual(preResult.count, 3)

        // Assert post-condition: all ignored
        XCTAssertEqual(postResult.count, 0)
    }

    func testAddRedactClasses_arrayAPI_shouldRedactCustomViews() throws {
        // -- Arrange --
        class V1: TestGridView {}
        class V2: TestGridView {}

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view1 = V1(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        rootView.addSubview(view1)

        let view2 = V2(frame: CGRect(x: 40, y: 10, width: 20, height: 20))
        rootView.addSubview(view2)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x169032310; frame = (0 0; 100 100); layer = <CALayer: 0x60000128bb00>>
        //   | <_TtCFC11SentryTests33SentryUIRedactBuilderTests_Common53testAddRedactClasses_arrayAPI_shouldRedactCustomViewsFzT_T_L_2V1: 0x14f5266e0; frame = (10 10; 20 20); layer = <CALayer: 0x6000012c2100>>
        //   | <_TtCFC11SentryTests33SentryUIRedactBuilderTests_Common53testAddRedactClasses_arrayAPI_shouldRedactCustomViewsFzT_T_L_2V2: 0x14f527130; frame = (40 10; 20 20); layer = <CALayer: 0x6000012c0a80>>

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)

        let preResult = sut.redactRegionsFor(view: rootView)
        let preMasked = createMaskedScreenshot(view: rootView, regions: preResult)

        sut.addRedactClasses([V1.self, V2.self])

        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: preMasked, as: .image)
        XCTAssertEqual(preResult.count, 0)

        assertSnapshot(of: masked, as: .image)
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 40, ty: 10))

        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Default ignored controls

    func testDefaultIgnoredControls_shouldNotRedactUISlider() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let slider = UISlider(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        rootView.addSubview(slider)

        // View Hierarchy:
        // ---------------
        // == iOS 26 ==
        // <UIView: 0x11b209710; frame = (0 0; 100 100); layer = <CALayer: 0x600000cd1440>>
        //   | <UISlider: 0x11b23e2e0; frame = (10 10; 80 20); opaque = NO; gestureRecognizers = <NSArray: 0x600000276be0>; layer = <CALayer: 0x600000ce80c0>; value: 0.000000>
        //   |    | <UIKit._UISliderGlassVisualElement: 0x11b25bdd0; frame = (0 0; 80 20); autoresize = W+H; layer = <CALayer: 0x600000cde0a0>>
        //   |    |    | <UIView: 0x11b439cb0; frame = (0 7; 80 6); clipsToBounds = YES; userInteractionEnabled = NO; layer = <CALayer: 0x600000cddc80>>
        //   |    |    |    | <UIView: 0x11b439ff0; frame = (0 0; 80 6); userInteractionEnabled = NO; backgroundColor = <UIDynamicProviderColor: 0x600000276c80; provider = <__NSMallocBlock__: 0x600000cdee20>>; layer = <CALayer: 0x600000cddef0>>
        //   |    |    |    | <UIView: 0x11b439e50; frame = (0 0; 0 6); userInteractionEnabled = NO; backgroundColor = <UITintColor: 0x600000276da0>; layer = <CALayer: 0x600000cdde60>>
        //   |    |    | <_UILiquidLensView: 0x11b25c050; frame = (0 -2; 37 24); layer = <CALayer: 0x600000cde2b0>>
        //   |    |    |    | <UIView: 0x11b22bf60; frame = (0 0; 37 24); autoresize = W+H; userInteractionEnabled = NO; layer = <CALayer: 0x600000ce9410>>
        //   |    |    |    |    | <UIView: 0x11b434710; frame = (0 0; 37 24); autoresize = W+H; userInteractionEnabled = NO; backgroundColor = <UIDynamicSystemColor: 0x600001749000; name = _controlForegroundColor>; layer = <CALayer: 0x600000cdd740>>
        //
        // == iOS 18 & 17 & 16 ==
        // <UIView: 0x12ed12bc0; frame = (0 0; 100 100); layer = <CALayer: 0x600001de3540>>
        //   | <UISlider: 0x13ed0f7e0; frame = (10 10; 80 20); opaque = NO; layer = <CALayer: 0x600001df0020>; value: 0.000000>
        //   |    | <_UISlideriOSVisualElement: 0x13ed0fbd0; frame = (0 0; 80 20); opaque = NO; autoresize = W+H; layer = <CALayer: 0x600001da7f80>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        // UISlider behavior differs by iOS version
        if #available(iOS 26.0, *) {
            // On iOS 26, UISlider uses a new visual implementation that creates clipping regions
            // even though the slider itself is in the ignore list
            let region0 = try XCTUnwrap(result.element(at: 0))
            XCTAssertNil(region0.color)
            XCTAssertEqual(region0.size, CGSize(width: 37, height: 24))
            XCTAssertEqual(region0.type, .clipOut)
            XCTAssertEqual(region0.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 8))

            let region1 = try XCTUnwrap(result.element(at: 1))
            XCTAssertNil(region1.color)
            XCTAssertEqual(region1.size, CGSize(width: 80, height: 6))
            XCTAssertEqual(region1.type, .clipBegin)
            XCTAssertEqual(region1.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 17))

            let region2 = try XCTUnwrap(result.element(at: 2))
            XCTAssertNil(region2.color)
            XCTAssertEqual(region2.size, CGSize(width: 0, height: 6))
            XCTAssertEqual(region2.type, .clipOut)
            XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 17))

            let region3 = try XCTUnwrap(result.element(at: 3))
            XCTAssertNil(region3.color)
            XCTAssertEqual(region3.size, CGSize(width: 80, height: 6))
            XCTAssertEqual(region3.type, .clipEnd)
            XCTAssertEqual(region3.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 17))

            // Assert that there are no other regions
            XCTAssertEqual(result.count, 4)
        } else {
            // On iOS < 26, UISlider is completely ignored (no regions)
            XCTAssertEqual(result.count, 0)
        }
    }

    func testDefaultIgnoredControls_shouldNotRedactUISwitch() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let toggle = UISwitch(frame: CGRect(x: 10, y: 40, width: 80, height: 30))
        toggle.title = "Off/On" // Setting a title for sanity check, it is not displayed on iOS
        rootView.addSubview(toggle)

        // View Hierarchy:
        // ---------------
        // === iOS 26 & 18 & 17 & 16 ===
        // <UIView: 0x11a5421b0; frame = (0 0; 100 100); layer = <CALayer: 0x600002407360>>
        //   | <UISwitch: 0x11a70f9e0; frame = (10 40; 51 31); gestureRecognizers = <NSArray: 0x600002b53e70>; layer = <CALayer: 0x600002444020>>
        //   |    | <UISwitchModernVisualElement: 0x11a710060; frame = (0 0; 51 31); gestureRecognizers = <NSArray: 0x600002b53a50>; layer = <CALayer: 0x6000024440c0>>
        //   |    |    | <UIView: 0x11a639760; frame = (0 0; 51 31); backgroundColor = UIExtendedSRGBColorSpace 0.470588 0.470588 0.501961 0.16; layer = <CALayer: 0x600002457000>>
        //   |    |    | <UIView: 0x11a638e20; frame = (0 0; 51 31); layer = <CALayer: 0x600002456f40>>
        //   |    |    |    | <UIImageView: 0x11a638c30; frame = (-459 0; 510 31); hidden = YES; opaque = NO; userInteractionEnabled = NO; layer = <CALayer: 0x600002455cc0>>
        //   |    |    |    | <UIView: 0x11a635710; frame = (0 0; 51 31); layer = <CALayer: 0x6000024b8480>>
        //   |    |    |    |    | <UIImageView: 0x11a639bf0; frame = (38.6667 16; 0 0); userInteractionEnabled = NO; tintColor = <UIDynamicSystemColor: 0x600003192a80; name = _switchOffImageColor>; layer = <CALayer: 0x6000024b8440>>
        //   |    |    |    | <UIImageView: 0x11a636ee0; frame = (12 16; 0 0); alpha = 0; userInteractionEnabled = NO; tintColor = UIExtendedGrayColorSpace 1 1; layer = <CALayer: 0x6000024b8460>>
        //   |    |    |    | <UIImageView: 0x11a63b980; frame = (-6 -3; 43 43); opaque = NO; userInteractionEnabled = NO; layer = <CALayer: 0x6000024572e0>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image, named: createTestDeviceOSBoundSnapshotName(name: "unmasked"))

        // Assert that UISwitch is not redacted (default ignored control)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Opacity & Background Edge Cases

    func testIsOpaque_withViewWithNilBackgroundColor_shouldReturnFalse() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        view.backgroundColor = nil
        rootView.addSubview(view)

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello"
        label.textColor = .orange
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        // View with nil backgroundColor should not be treated as opaque
        // So the label should still be redacted
        assertSnapshot(of: masked, as: .image)
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.color, UIColor.orange)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testIsOpaque_withViewWithTransparentBackgroundColor_shouldReturnFalse() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        view.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        rootView.addSubview(view)

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello"
        label.textColor = .orange
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        // View with transparent backgroundColor should not be treated as opaque
        // So the label should still be redacted
        assertSnapshot(of: masked, as: .image)
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.color, UIColor.orange)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testIsOpaque_withLayerOpacityLessThanOne_shouldReturnFalse() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let view = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        view.backgroundColor = .white
        view.alpha = 0.5
        rootView.addSubview(view)

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello World"
        label.textColor = .purple
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        // View with layer opacity < 1 should not be treated as opaque
        // So the label should still be redacted
        assertSnapshot(of: masked, as: .image)
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.color, UIColor.purple)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Class Hierarchy Edge Cases

    func testContainsIgnoreClass_withExactClass_shouldMatch() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        let sut = getSut(maskAllText: true, maskAllImages: true)

        // -- Act --
        // Check pre-condition: label should be redacted by default
        let preIgnoreResult = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(preIgnoreResult.count, 1)
        
        // Add UILabel to ignore list
        sut.addIgnoreClass(UILabel.self)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Label should be ignored because UILabel is in the ignore list
        XCTAssertEqual(result.count, 0)
    }
}

// MARK: - Test Views

private class TestCustomVisibilityView: UIView {
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

private class TestGridView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        // Draws a 2x2 grid with each quadrant a different color: red, green, blue, purple.
        // The masking color is an average so it will look different in snapshots.
        //
        // We are directly drawing this grid without any further subviews or sublayers because
        // they would be picked up by the redaction algorithm
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let midX = bounds.midX
        let midY = bounds.midY

        // Top-left (red)
        ctx.setFillColor(UIColor.red.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: midX, height: midY))

        // Top-right (green)
        ctx.setFillColor(UIColor.green.cgColor)
        ctx.fill(CGRect(x: midX, y: 0, width: bounds.width - midX, height: midY))

        // Bottom-left (blue)
        ctx.setFillColor(UIColor.blue.cgColor)
        ctx.fill(CGRect(x: 0, y: midY, width: midX, height: bounds.height - midY))

        // Bottom-right (purple)
        ctx.setFillColor(UIColor.orange.cgColor)
        ctx.fill(CGRect(x: midX, y: midY, width: bounds.width - midX, height: bounds.height - midY))
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
// swiftlint:enable file_length
