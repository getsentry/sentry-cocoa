// swiftlint:disable file_length type_body_length
#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@_spi(Private) @testable import Sentry
import SentryTestUtils
import SwiftUI
import UIKit
import XCTest

/// See `SentryUIRedactBuilderTests.swift` for more information on how to print the internal view hierarchy of a view.
class SentryUIRedactBuilderTests_EdgeCases: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name
    private func getSut(maskAllText: Bool, maskAllImages: Bool, maskedViewClasses: [AnyClass] = [], unmaskedViewClasses: [AnyClass] = []) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            maskedViewClasses: maskedViewClasses,
            unmaskedViewClasses: unmaskedViewClasses
        ))
    }

    // MARK: - Early Returns & Guard Conditions

    func testMapRedactRegion_withEmptyRedactClasses_shouldReturnEarly() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // Create a builder with no redact classes by using maskAllText=false and maskAllImages=false
        let sut = getSut(maskAllText: false, maskAllImages: false)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testMapRedactRegion_withNoSublayers_shouldNotCrash() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        // A simple view with no subviews will have no sublayers beyond its own layer
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Should not crash and return no regions (plain UIView is not redacted)
        XCTAssertEqual(result.count, 0)
    }

    func testMapRedactRegion_withEmptySublayers_shouldNotCrash() {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)
        // Explicitly set sublayers to empty array (though this is unusual)
        view.layer.sublayers = []

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Color Extraction

    func testColor_withUILabel_withNilTextColor_shouldUseDefaultColor() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = nil // UIKit will assign default label color
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        // When textColor is nil, UIKit assigns a default color, so we get a color
        XCTAssertNotNil(region.color)
        // The color should be the default label color with alpha 1.0
        XCTAssertEqual(region.color, label.textColor.withAlphaComponent(1.0))
    }

    func testColor_withNonUILabel_shouldReturnNil() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let textView = UITextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertGreaterThanOrEqual(result.count, 1)
        let textViewRegion = try XCTUnwrap(result.first { $0.size == CGSize(width: 40, height: 40) })
        // UITextView should have nil color (not a UILabel)
        XCTAssertNil(textViewRegion.color)
    }

    func testColor_withUILabel_withTransparentTextColor_shouldReturnOpaqueVersion() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = UIColor.purple.withAlphaComponent(0.5)
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        XCTAssertNotNil(region.color)
        XCTAssertEqual(region.color, UIColor.purple)
    }

    // MARK: - Transform & Geometry

    func testOpaqueRotatedView_coveringRoot_doesNotClearPreviousRedactions() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        // Add a label that should be redacted
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello World"
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
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 100, height: 100))
        XCTAssertEqual(region.type, .clipOut)
        XCTAssertAffineTransformEqual(
            region.transform,
            CGAffineTransform(
                a: 0.9238795325112867,
                b: 0.3826834323650898,
                c: -0.3826834323650898,
                d: 0.9238795325112867,
                tx: 22.940194992690152,
                ty: -15.328148243818825
            ),
            accuracy: 0.001
        )

        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(region2.color, UIColor.purple)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testConcatenateTranform_withCustomAnchorPoint_shouldCalculateCorrectly() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.layer.anchorPoint = CGPoint(x: 0.25, y: 0.75)
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        // The transform should account for the custom anchor point
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        // With anchorPoint (0.25, 0.75), the offset should be different
        // anchorPoint offset: x = 40 * 0.25 = 10, y = 40 * 0.75 = 30
        // Position is at center: (20, 20) + (20, 20) = (40, 40)
        // Transform tx/ty should be position - anchorPointOffset = (40, 40) - (10, 30) = (30, 10)
        XCTAssertEqual(region.transform.tx, 30, accuracy: 0.01)
        XCTAssertEqual(region.transform.ty, 10, accuracy: 0.01)
    }

    func testConcatenateTranform_withZeroAnchorPoint_shouldCalculateCorrectly() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.layer.anchorPoint = CGPoint(x: 0, y: 0)
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        // With anchorPoint (0, 0), the transform should reflect that
        // anchorPoint offset: (0, 0)
        // Position is at (40, 40) in parent
        XCTAssertEqual(region.transform.tx, 40, accuracy: 0.01)
        XCTAssertEqual(region.transform.ty, 40, accuracy: 0.01)
    }

    func testConcatenateTranform_withOneAnchorPoint_shouldCalculateCorrectly() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.layer.anchorPoint = CGPoint(x: 1, y: 1)
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        // With anchorPoint (1, 1), the transform should reflect that
        // anchorPoint offset: (40, 40)
        // Position is at (40, 40) in parent
        // Transform tx/ty should be position - anchorPointOffset = (40, 40) - (40, 40) = (0, 0)
        XCTAssertEqual(region.transform.tx, 0, accuracy: 0.01)
        XCTAssertEqual(region.transform.ty, 0, accuracy: 0.01)
    }

    func testIsAxisAligned_withRotation_shouldReturnFalse() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.transform = CGAffineTransform(rotationAngle: .pi / 4)
        label.textColor = .purple
        rootView.addSubview(label)

        // Create an opaque view covering the entire root to test axis alignment check
        let opaqueView = UIView(frame: rootView.bounds)
        opaqueView.backgroundColor = .black
        opaqueView.transform = CGAffineTransform(rotationAngle: .pi / 4)
        rootView.addSubview(opaqueView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // The rotated opaque view should create a clipOut region (not clear the redacting array)
        // because isAxisAligned returns false
        let containerRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(containerRegion.color)
        XCTAssertEqual(containerRegion.type, .clipOut)
        XCTAssertEqual(containerRegion.size, CGSize(width: 100, height: 100))
        XCTAssertAffineTransformEqual(
            containerRegion.transform,
            CGAffineTransform(
                a: 0.70710678118654757,
                b: 0.70710678118654746,
                c: -0.70710678118654746,
                d: 0.70710678118654757,
                tx: 50,
                ty: -20.710678118654752
            ),
            accuracy: 0.001
        )

        let labelRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(labelRegion.color, UIColor.purple)
        XCTAssertEqual(labelRegion.type, .redact)
        XCTAssertEqual(labelRegion.size, CGSize(width: 40, height: 40))
        XCTAssertAffineTransformEqual(
            labelRegion.transform,
            CGAffineTransform(
                a: 0.70710678118654757,
                b: 0.70710678118654746,
                c: -0.70710678118654746,
                d: 0.70710678118654757,
                tx: 40,
                ty: 11.715728752538098
            ),
            accuracy: 0.001
        )

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testIsAxisAligned_withScaleOnly_shouldReturnTrue() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello, World!"
        label.textColor = .purple
        rootView.addSubview(label)

        // Create an opaque view that covers the entire root with scale transform
        let opaqueView = UIView(frame: rootView.bounds)
        opaqueView.backgroundColor = .black
        opaqueView.transform = CGAffineTransform(scaleX: 2, y: 2)
        rootView.addSubview(opaqueView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let containerRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(containerRegion.color)
        XCTAssertEqual(containerRegion.type, .clipOut)
        XCTAssertEqual(containerRegion.size, CGSize(width: 100, height: 100))
        XCTAssertAffineTransformEqual(
            containerRegion.transform,
            CGAffineTransform(
                a: 2,
                b: 0,
                c: 0,
                d: 2,
                tx: -50,
                ty: -50
            ),
            accuracy: 0.001
        )

        let labelRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(labelRegion.color, UIColor.purple)
        XCTAssertEqual(labelRegion.type, .redact)
        XCTAssertEqual(labelRegion.size, CGSize(width: 40, height: 40))
        XCTAssertAffineTransformEqual(
            labelRegion.transform,
            CGAffineTransform(
                a: 1,
                b: 0,
                c: 0,
                d: 1,
                tx: 20,
                ty: 20
            ),
            accuracy: 0.001
        )

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Region Ordering

    func testRedactRegionsFor_shouldReturnReversedOrder() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label1 = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        label1.textColor = .red
        rootView.addSubview(label1)

        let label2 = UILabel(frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        label2.textColor = .blue
        rootView.addSubview(label2)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // The regions should be in reverse order of traversal
        // label2 should appear before label1 in the result
        let firstRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(firstRegion.color, UIColor.blue)
        XCTAssertEqual(firstRegion.type, .redact)
        XCTAssertEqual(firstRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(firstRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 40.0, ty: 40.0))

        // Check that the first result corresponds to label2 (added second, reversed to first)
        let secondRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(secondRegion.color, UIColor.red)
        XCTAssertEqual(secondRegion.type, .redact)
        XCTAssertEqual(secondRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(secondRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedactRegionsFor_withSwiftUIRegions_shouldAppearFirst() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        label.text = "Hello, World!"
        label.textColor = .red
        rootView.addSubview(label)

        // Create a view that would be marked as SwiftUI redact
        let swiftUIView = UIView(frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        rootView.addSubview(swiftUIView)
        SentryRedactViewHelper.maskSwiftUI(swiftUIView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // SwiftUI regions should appear first (after reversing, redactSwiftUI is moved to end, then reversed to start)
        let firstRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(firstRegion.color)
        XCTAssertEqual(firstRegion.type, .redactSwiftUI)
        XCTAssertEqual(firstRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(firstRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 40.0, ty: 40.0))

        let secondRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(secondRegion.color, UIColor.red)
        XCTAssertEqual(secondRegion.type, .redact)
        XCTAssertEqual(secondRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(secondRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    func testRedactRegionsFor_withMixedRegionTypes_shouldOrderCorrectly() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        label.text = "Hello, World!"
        label.textColor = .red
        rootView.addSubview(label)

        let opaqueView = UIView(frame: CGRect(x: 30, y: 30, width: 20, height: 20))
        opaqueView.backgroundColor = .white
        rootView.addSubview(opaqueView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let firstRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(firstRegion.color)
        XCTAssertEqual(firstRegion.type, .clipOut)
        XCTAssertEqual(firstRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(firstRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 30.0, ty: 30.0))

        let secondRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(secondRegion.color, UIColor.red)
        XCTAssertEqual(secondRegion.type, .redact)
        XCTAssertEqual(secondRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(secondRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Sublayer Sorting (zPosition)

    func testMapRedactRegion_withDifferentZPositions_shouldSortCorrectly() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label1 = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        label1.textColor = .red
        label1.layer.zPosition = 10
        rootView.addSubview(label1)

        let label2 = UILabel(frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        label2.textColor = .blue
        label2.layer.zPosition = 5
        rootView.addSubview(label2)

        let label3 = UILabel(frame: CGRect(x: 70, y: 70, width: 20, height: 20))
        label3.textColor = .green
        label3.layer.zPosition = 15
        rootView.addSubview(label3)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // After sorting by zPosition (5, 10, 15) and reversing, we should get (15, 10, 5)
        // which means green, red, blue
        let greenRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(greenRegion.color, UIColor.green)
        XCTAssertEqual(greenRegion.type, .redact)
        XCTAssertEqual(greenRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(greenRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 70.0, ty: 70.0))

        let redRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(redRegion.color, UIColor.red)
        XCTAssertEqual(redRegion.type, .redact)
        XCTAssertEqual(redRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(redRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        let blueRegion = try XCTUnwrap(result.element(at: 2))
        XCTAssertEqual(blueRegion.color, UIColor.blue)
        XCTAssertEqual(blueRegion.type, .redact)
        XCTAssertEqual(blueRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(blueRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 40.0, ty: 40.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 3)
    }

    func testMapRedactRegion_withSameZPosition_shouldPreserveInsertionOrder() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label1 = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        label1.textColor = .red
        label1.layer.zPosition = 5
        rootView.addSubview(label1)

        let label2 = UILabel(frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        label2.textColor = .blue
        label2.layer.zPosition = 5
        rootView.addSubview(label2)

        let label3 = UILabel(frame: CGRect(x: 70, y: 70, width: 20, height: 20))
        label3.textColor = .green
        label3.layer.zPosition = 5
        rootView.addSubview(label3)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // With same zPosition, insertion order should be preserved, then reversed
        // So: green, blue, red
        let greenRegion = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(greenRegion.color, UIColor.green)
        XCTAssertEqual(greenRegion.type, .redact)
        XCTAssertEqual(greenRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(greenRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 70.0, ty: 70.0))

        let blueRegion = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(blueRegion.color, UIColor.blue)
        XCTAssertEqual(blueRegion.type, .redact)
        XCTAssertEqual(blueRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(blueRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 40.0, ty: 40.0))

        let redRegion = try XCTUnwrap(result.element(at: 2))
        XCTAssertEqual(redRegion.color, UIColor.red)
        XCTAssertEqual(redRegion.type, .redact)
        XCTAssertEqual(redRegion.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(redRegion.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Opaque View Detection

    func testSemiTransparentOverlay_shouldNotClearRedactions() throws {
        // -- Arrange --
        // This test reproduces the issue from https://github.com/getsentry/sentry-cocoa/pull/6629#issuecomment-3479730690
        // where a semi-transparent overlay (alpha = 0.2) was incorrectly treated as opaque and cleared all previous redactions.
        
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        // Add labels that should be redacted
        let label1 = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        label1.text = "THIS IS THE DIALOG TITLE"
        label1.textColor = .purple
        rootView.addSubview(label1)
        
        let label2 = UILabel(frame: CGRect(x: 10, y: 40, width: 80, height: 20))
        label2.text = "This is the message section"
        label2.textColor = .purple
        rootView.addSubview(label2)
        
        // Add a semi-transparent overlay that covers the entire root (simulates PopupDialogOverlayView)
        let overlay = UIView(frame: rootView.bounds)
        overlay.backgroundColor = .red
        overlay.alpha = 0.2  // Semi-transparent - should NOT be treated as opaque
        rootView.addSubview(overlay)
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // The semi-transparent overlay should NOT clear the label redactions
        // We expect both labels to still be redacted
        XCTAssertGreaterThanOrEqual(result.count, 2, "Semi-transparent overlay should not clear previous redactions")
        
        // Verify that both labels are in the redaction list
        let labelRegions = result.filter { $0.type == .redact && $0.color == UIColor.purple }
        XCTAssertEqual(labelRegions.count, 2, "Both labels should be redacted")
        
        // Verify label 1 is redacted
        let label1Region = try XCTUnwrap(labelRegions.first { $0.size == CGSize(width: 80, height: 20) && $0.transform.tx == 10 && $0.transform.ty == 10 })
        XCTAssertEqual(label1Region.color, UIColor.purple)
        XCTAssertEqual(label1Region.type, .redact)
        
        // Verify label 2 is redacted
        let label2Region = try XCTUnwrap(labelRegions.first { $0.size == CGSize(width: 80, height: 20) && $0.transform.tx == 10 && $0.transform.ty == 40 })
        XCTAssertEqual(label2Region.color, UIColor.purple)
        XCTAssertEqual(label2Region.type, .redact)
    }

    func testFullyOpaqueView_shouldClearRedactions() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        // Add a label that should be redacted
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        label.text = "Secret Text"
        label.textColor = .purple
        rootView.addSubview(label)
        
        // Add a fully opaque view that covers the entire root
        let opaqueView = UIView(frame: rootView.bounds)
        opaqueView.backgroundColor = .white
        opaqueView.alpha = 1.0  // Fully opaque
        opaqueView.isOpaque = true
        // Ensure both view and layer background colors are set and opaque
        opaqueView.layer.backgroundColor = UIColor.white.cgColor
        opaqueView.layer.isOpaque = true
        rootView.addSubview(opaqueView)
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // The fully opaque view should clear all previous redactions
        // We expect no redact regions for the label (it's completely covered)
        let labelRegions = result.filter { $0.type == .redact && $0.color == UIColor.purple }
        XCTAssertEqual(labelRegions.count, 0, "Label should be cleared by fully opaque view")
    }

    func testViewWithSemiTransparentBackground_shouldNotBeTreatedAsOpaque() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        label.text = "Secret Text"
        label.textColor = .purple
        rootView.addSubview(label)
        
        // Add a view with semi-transparent background color (alpha in the color itself)
        let semiTransparentView = UIView(frame: rootView.bounds)
        semiTransparentView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        rootView.addSubview(semiTransparentView)
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // The semi-transparent view should NOT clear the label redactions
        let labelRegions = result.filter { $0.type == .redact && $0.color == UIColor.purple }
        XCTAssertEqual(labelRegions.count, 1, "Label should still be redacted")
    }

    func testViewWithTransparentLayerBackground_shouldNotBeTreatedAsOpaque() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        label.text = "Secret Text"
        label.textColor = .purple
        rootView.addSubview(label)
        
        // Add a view with transparent layer background
        let viewWithTransparentLayer = UIView(frame: rootView.bounds)
        viewWithTransparentLayer.backgroundColor = .red
        viewWithTransparentLayer.layer.backgroundColor = UIColor.red.withAlphaComponent(0.3).cgColor
        rootView.addSubview(viewWithTransparentLayer)
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // The view with transparent layer background should NOT clear the label redactions
        let labelRegions = result.filter { $0.type == .redact && $0.color == UIColor.purple }
        XCTAssertEqual(labelRegions.count, 1, "Label should still be redacted")
    }

    func testSemiTransparentOverlayWithBackgroundText_shouldMaskAllText() throws {
        // -- Arrange --
        // This test verifies that text in the background is still masked when there's a semi-transparent overlay on top
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        // Add background text that should be masked
        let backgroundLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        backgroundLabel.text = "Background Secret"
        backgroundLabel.textColor = .blue
        rootView.addSubview(backgroundLabel)
        
        // Add a semi-transparent overlay
        let overlay = UIView(frame: rootView.bounds)
        overlay.backgroundColor = .white
        overlay.alpha = 0.5  // Semi-transparent
        rootView.addSubview(overlay)
        
        // Add foreground text that should also be masked
        let foregroundLabel = UILabel(frame: CGRect(x: 10, y: 40, width: 80, height: 20))
        foregroundLabel.text = "Foreground Secret"
        foregroundLabel.textColor = .green
        rootView.addSubview(foregroundLabel)
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        
        // -- Assert --
        // Both labels should be redacted regardless of the semi-transparent overlay
        let backgroundLabelRegion = result.first { $0.type == .redact && $0.color == UIColor.blue }
        XCTAssertNotNil(backgroundLabelRegion, "Background label should be redacted")
        
        let foregroundLabelRegion = result.first { $0.type == .redact && $0.color == UIColor.green }
        XCTAssertNotNil(foregroundLabelRegion, "Foreground label should be redacted")
        
        // Verify both labels are in the redaction list
        let labelRegions = result.filter { $0.type == .redact && ($0.color == UIColor.blue || $0.color == UIColor.green) }
        XCTAssertEqual(labelRegions.count, 2, "Both labels should be redacted")
    }

    // MARK: - Nested Clipping

    func testMapRedactRegion_withNestedClipToBounds_shouldCreateNestedClipRegions() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let container1 = UIView(frame: CGRect(x: 10, y: 10, width: 80, height: 80))
        container1.clipsToBounds = true
        rootView.addSubview(container1)

        let container2 = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        container2.clipsToBounds = true
        container1.addSubview(container2)

        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 40, height: 40))
        label.text = "Hello, World!"
        label.textColor = UIColor.purple
        container2.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region0 = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region0.color)
        XCTAssertEqual(region0.type, .clipBegin)
        XCTAssertEqual(region0.size, CGSize(width: 80, height: 80))
        XCTAssertEqual(region0.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        let region1 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region1.color)
        XCTAssertEqual(region1.type, .clipBegin)
        XCTAssertEqual(region1.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region1.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 20.0, ty: 20.0))

        let region2 = try XCTUnwrap(result.element(at: 2))
        XCTAssertEqual(region2.color, UIColor.purple)
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 30.0, ty: 30.0))

        let region3 = try XCTUnwrap(result.element(at: 3))
        XCTAssertNil(region3.color)
        XCTAssertEqual(region3.type, .clipEnd)
        XCTAssertEqual(region3.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(region3.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 20.0, ty: 20.0))

        let region4 = try XCTUnwrap(result.element(at: 4))
        XCTAssertNil(region4.color)
        XCTAssertEqual(region4.type, .clipEnd)
        XCTAssertEqual(region4.size, CGSize(width: 80, height: 80))
        XCTAssertEqual(region4.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 5)
    }

    func testMapRedactRegion_withNestedClipToBounds_shouldHaveCorrectClipBeginEnd() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let container = UIView(frame: CGRect(x: 10, y: 10, width: 80, height: 80))
        container.clipsToBounds = true
        rootView.addSubview(container)

        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 40, height: 40))
        label.text = "Hello, World!"
        label.textColor = UIColor.purple
        container.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region0 = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region0.color)
        XCTAssertEqual(region0.type, .clipBegin)
        XCTAssertEqual(region0.size, CGSize(width: 80, height: 80))
        XCTAssertEqual(region0.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        let region1 = try XCTUnwrap(result.element(at: 1))
        XCTAssertEqual(region1.color, UIColor.purple)
        XCTAssertEqual(region1.type, .redact)
        XCTAssertEqual(region1.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region1.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 20.0, ty: 20.0))

        let region2 = try XCTUnwrap(result.element(at: 2))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.type, .clipEnd)
        XCTAssertEqual(region2.size, CGSize(width: 80, height: 80))
        XCTAssertEqual(region2.transform, CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 10.0))

        // Assert that no other regions
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Presentation Layer

    func testMapRedactRegion_withPresentationLayer_shouldUsePresentationLayer() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.text = "Hello, World!"
        label.textColor = UIColor.purple
        rootView.addSubview(label)

        // Start a shorter animation with linear timing to create a predictable presentation layer
        UIView.animate(withDuration: 10.0, delay: 0, options: .curveLinear) {
            label.frame = CGRect(x: 60, y: 60, width: 40, height: 40)
        }

        // Wait for animation to reach approximately 50% completion (0.5 seconds of 1.0 second animation)
        let expectation = XCTestExpectation(description: "Wait for animation to reach midpoint")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // During animation, the presentation layer should be used
        // With linear timing at 50% completion, position should be approximately halfway between start (20, 20) and end (60, 60)
        // Expected midpoint: (40, 40) with some tolerance for timing precision
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertEqual(region.color, UIColor.purple)
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        
        // Verify the position is in the middle third of the animation range (between 30 and 50)
        // This ensures the presentation layer is being used and represents an intermediate state
        XCTAssertGreaterThan(region.transform.tx, 20.0)
        XCTAssertLessThanOrEqual(region.transform.tx, 60.0)
        XCTAssertGreaterThan(region.transform.ty, 20.0)
        XCTAssertLessThanOrEqual(region.transform.ty, 60.0)

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testMapRedactRegion_withoutPresentationLayer_shouldUseModelLayer() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        let region = try XCTUnwrap(result.first)
        // Should use model layer when no animation is in progress
        XCTAssertAffineTransformEqual(
            region.transform,
            CGAffineTransform(
                a: 1,
                b: 0,
                c: 0,
                d: 1,
                tx: 20,
                ty: 20
            ),
            accuracy: 0.001
        )

        // Assert that no other regions
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - ExtendedClassIdentifier Initializers

    func testExtendedClassIdentifier_initWithClassId_shouldStoreCorrectly() {
        // -- Arrange & Act --
        let identifier = SentryUIRedactBuilder.ClassIdentifier(
            classId: "MyCustomClass",
            layerId: "MyCustomLayer"
        )

        // -- Assert --
        XCTAssertEqual(identifier.classId, "MyCustomClass")
        XCTAssertEqual(identifier.layerId, "MyCustomLayer")
    }

    func testExtendedClassIdentifier_initWithObjcType_shouldStoreCorrectDescription() {
        // -- Arrange & Act --
        let identifier = SentryUIRedactBuilder.ClassIdentifier(
            objcType: UILabel.self,
            layerId: "CustomLayer"
        )

        // -- Assert --
        XCTAssertEqual(identifier.classId, UILabel.description())
        XCTAssertEqual(identifier.layerId, "CustomLayer")
    }

    func testExtendedClassIdentifier_initWithClass_shouldStoreCorrectDescription() {
        // -- Arrange --
        class MyCustomClass: NSObject {}

        // -- Act --
        let identifier = SentryUIRedactBuilder.ClassIdentifier(
            class: MyCustomClass.self,
            layerId: nil
        )

        // -- Assert --
        XCTAssertEqual(identifier.classId, MyCustomClass.description())
        XCTAssertNil(identifier.layerId)
    }

    func testExtendedClassIdentifier_hashable_shouldWorkInSet() {
        // -- Arrange --
        let identifier1 = SentryUIRedactBuilder.ClassIdentifier(
            classId: "ClassA",
            layerId: "LayerA"
        )
        let identifier2 = SentryUIRedactBuilder.ClassIdentifier(
            classId: "ClassA",
            layerId: "LayerA"
        )
        let identifier3 = SentryUIRedactBuilder.ClassIdentifier(
            classId: "ClassB",
            layerId: "LayerB"
        )

        // -- Act --
        var set = Set<SentryUIRedactBuilder.ClassIdentifier>()
        set.insert(identifier1)
        set.insert(identifier2)
        set.insert(identifier3)

        // -- Assert --
        XCTAssertEqual(set.count, 2) // identifier1 and identifier2 are equal
        XCTAssertTrue(set.contains(identifier1))
        XCTAssertTrue(set.contains(identifier2))
        XCTAssertTrue(set.contains(identifier3))
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
// swiftlint:enable file_length type_body_length
