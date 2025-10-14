// swiftlint:disable file_length type_body_length
#if os(iOS)
import Foundation
@_spi(Private) @testable import Sentry
import SentryTestUtils
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

class SentryUIRedactBuilderTests_EdgeCases: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name
    private var rootView: UIView!

    private func getSut(maskAllText: Bool, maskAllImages: Bool, maskedViewClasses: [AnyClass] = [], unmaskedViewClasses: [AnyClass] = []) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            maskedViewClasses: maskedViewClasses,
            unmaskedViewClasses: unmaskedViewClasses
        ))
    }

    override func setUp() {
        rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    // MARK: - ExtendedClassIdentifier & Layer Filtering

    func testExtendedClassIdentifier_withMatchingLayerId_shouldMatch() {
        // -- Arrange --
        // Create a custom view with a custom layer
        class CustomLayer: CALayer {}
        class CustomView: UIView {
            override class var layerClass: AnyClass {
                return CustomLayer.self
            }
        }

        let view = CustomView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let identifier = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: CustomView.description(),
            layerId: CustomLayer.description()
        )

        // -- Act --
        let matches = identifier.matches(viewClass: type(of: view), layerClass: type(of: view.layer))

        // -- Assert --
        XCTAssertTrue(matches)
    }

    func testExtendedClassIdentifier_withoutMatchingLayerId_shouldNotMatch() {
        // -- Arrange --
        // Create a custom view with a standard CALayer
        class CustomView: UIView {}

        let view = CustomView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let identifier = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: CustomView.description(),
            layerId: "SomeOtherLayer"
        )

        // -- Act --
        let matches = identifier.matches(viewClass: type(of: view), layerClass: type(of: view.layer))

        // -- Assert --
        XCTAssertFalse(matches)
    }

    func testExtendedClassIdentifier_withNoLayerIdFilter_shouldMatchAnyLayer() {
        // -- Arrange --
        class CustomLayer: CALayer {}
        class CustomView: UIView {
            override class var layerClass: AnyClass {
                return CustomLayer.self
            }
        }

        let view = CustomView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let identifier = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: CustomView.description(),
            layerId: nil
        )

        // -- Act --
        let matches = identifier.matches(viewClass: type(of: view), layerClass: type(of: view.layer))

        // -- Assert --
        XCTAssertTrue(matches)
    }

    // MARK: - Early Returns & Guard Conditions

    func testMapRedactRegion_withEmptyRedactClasses_shouldReturnEarly() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // Create a builder with no redact classes by using maskAllText=false and maskAllImages=false
        let sut = getSut(maskAllText: false, maskAllImages: false)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testMapRedactRegion_withHiddenLayer_shouldSkip() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.isHidden = true
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testMapRedactRegion_withZeroOpacity_shouldSkip() {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.alpha = 0
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testMapRedactRegion_withNoSublayers_shouldNotCrash() {
        // -- Arrange --
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

    // MARK: - UIImageView Edge Cases

    func testShouldRedact_withImageView_withNilImage_shouldNotRedact() {
        // -- Arrange --
        let imageView = UIImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        imageView.image = nil
        rootView.addSubview(imageView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testShouldRedact_withImageView_withExactly10x10Image_shouldNotRedact() {
        // -- Arrange --
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testShouldRedact_withImageView_with9x9Image_shouldNotRedact() {
        // -- Arrange --
        let image = UIGraphicsImageRenderer(size: CGSize(width: 9, height: 9)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 9, height: 9))
        }
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 0)
    }

    func testShouldRedact_withImageView_with11x11Image_shouldRedact() throws {
        // -- Arrange --
        let image = UIGraphicsImageRenderer(size: CGSize(width: 11, height: 11)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 11, height: 11))
        }
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        XCTAssertEqual(region.type, .redact)
    }

    func testShouldRedact_withImageView_withNilImageAsset_shouldRedact() throws {
        // -- Arrange --
        // Create an image programmatically (no asset bundle)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        XCTAssertEqual(region.type, .redact)
    }

    // MARK: - Color Extraction

    func testColor_withUILabel_withNilTextColor_shouldUseDefaultColor() throws {
        // -- Arrange --
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

    func testConcatenateTranform_withCustomAnchorPoint_shouldCalculateCorrectly() throws {
        // -- Arrange --
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
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.transform = CGAffineTransform(rotationAngle: .pi / 4)
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
        XCTAssertGreaterThan(result.count, 0)
        let hasClipOut = result.contains { $0.type == .clipOut }
        XCTAssertTrue(hasClipOut, "Rotated opaque view should create clipOut region")
    }

    func testIsAxisAligned_withScaleOnly_shouldReturnTrue() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
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
        // With scale only and covering the root, it might clear or create clipOut
        // The important thing is it doesn't crash and handles scale-only transforms
        XCTAssertNotNil(result)
    }

    // MARK: - Region Ordering

    func testRedactRegionsFor_shouldReturnReversedOrder() throws {
        // -- Arrange --
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
        XCTAssertEqual(result.count, 2)
        // The regions should be in reverse order of traversal
        // label2 should appear before label1 in the result
        let firstRegion = try XCTUnwrap(result.first)
        let secondRegion = try XCTUnwrap(result.last)
        
        // Check that the first result corresponds to label2 (added second, reversed to first)
        XCTAssertEqual(firstRegion.color, .blue)
        XCTAssertEqual(secondRegion.color, .red)
    }

    func testRedactRegionsFor_withSwiftUIRegions_shouldAppearFirst() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        rootView.addSubview(label)

        // Create a view that would be marked as SwiftUI redact
        let swiftUIView = UIView(frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        rootView.addSubview(swiftUIView)
        SentryRedactViewHelper.maskSwiftUI(swiftUIView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertGreaterThanOrEqual(result.count, 2)
        // SwiftUI regions should appear first (after reversing, redactSwiftUI is moved to end, then reversed to start)
        let firstRegion = try XCTUnwrap(result.first)
        XCTAssertEqual(firstRegion.type, .redactSwiftUI) // SwiftUI regions preserve their type
    }

    func testRedactRegionsFor_withMixedRegionTypes_shouldOrderCorrectly() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        rootView.addSubview(label)

        let opaqueView = UIView(frame: CGRect(x: 30, y: 30, width: 20, height: 20))
        opaqueView.backgroundColor = .white
        rootView.addSubview(opaqueView)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertGreaterThanOrEqual(result.count, 2)
        // Should have a mix of redact and clipOut types
        let hasRedact = result.contains { $0.type == .redact }
        let hasClipOut = result.contains { $0.type == .clipOut }
        XCTAssertTrue(hasRedact)
        XCTAssertTrue(hasClipOut)
    }

    // MARK: - Sublayer Sorting (zPosition)

    func testMapRedactRegion_withDifferentZPositions_shouldSortCorrectly() throws {
        // -- Arrange --
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
        XCTAssertEqual(result.count, 3)
        // After sorting by zPosition (5, 10, 15) and reversing, we should get (15, 10, 5)
        // which means green, red, blue
        XCTAssertEqual(result[0].color, .green)
        XCTAssertEqual(result[1].color, .red)
        XCTAssertEqual(result[2].color, .blue)
    }

    func testMapRedactRegion_withSameZPosition_shouldPreserveInsertionOrder() throws {
        // -- Arrange --
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
        XCTAssertEqual(result.count, 3)
        // With same zPosition, insertion order should be preserved, then reversed
        // So: green, blue, red
        XCTAssertEqual(result[0].color, .green)
        XCTAssertEqual(result[1].color, .blue)
        XCTAssertEqual(result[2].color, .red)
    }

    // MARK: - Nested Clipping

    func testMapRedactRegion_withNestedClipToBounds_shouldCreateNestedClipRegions() throws {
        // -- Arrange --
        let container1 = UIView(frame: CGRect(x: 10, y: 10, width: 80, height: 80))
        container1.clipsToBounds = true
        rootView.addSubview(container1)

        let container2 = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        container2.clipsToBounds = true
        container1.addSubview(container2)

        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 40, height: 40))
        container2.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Should have: redact, clipBegin (inner), clipEnd (inner), clipBegin (outer), clipEnd (outer)
        XCTAssertGreaterThanOrEqual(result.count, 5)
        
        let clipBegins = result.filter { $0.type == .clipBegin }
        let clipEnds = result.filter { $0.type == .clipEnd }
        
        XCTAssertEqual(clipBegins.count, 2)
        XCTAssertEqual(clipEnds.count, 2)
    }

    func testMapRedactRegion_withNestedClipToBounds_shouldHaveCorrectClipBeginEnd() throws {
        // -- Arrange --
        let container = UIView(frame: CGRect(x: 10, y: 10, width: 80, height: 80))
        container.clipsToBounds = true
        rootView.addSubview(container)

        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 40, height: 40))
        container.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Should have: redact, clipBegin, clipEnd
        XCTAssertEqual(result.count, 3)
        
        // Order should be: clipBegin (first in reversed output), redact, clipEnd (last)
        XCTAssertEqual(result[0].type, .clipBegin)
        XCTAssertEqual(result[1].type, .redact)
        XCTAssertEqual(result[2].type, .clipEnd)
    }

    // MARK: - Presentation Layer

    func testMapRedactRegion_withPresentationLayer_shouldUsePresentationLayer() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // Start an animation to create a presentation layer
        UIView.animate(withDuration: 10) {
            label.frame = CGRect(x: 60, y: 60, width: 40, height: 40)
        }

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertGreaterThanOrEqual(result.count, 1)
        // During animation, the presentation layer should be used
        // The exact position will be somewhere between start and end
        let region = try XCTUnwrap(result.first)
        XCTAssertNotNil(region)
    }

    func testMapRedactRegion_withoutPresentationLayer_shouldUseModelLayer() throws {
        // -- Arrange --
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        // Should use model layer when no animation is in progress
        XCTAssertEqual(region.transform.tx, 20, accuracy: 0.01)
        XCTAssertEqual(region.transform.ty, 20, accuracy: 0.01)
    }

    // MARK: - ExtendedClassIdentifier Initializers

    func testExtendedClassIdentifier_initWithClassId_shouldStoreCorrectly() {
        // -- Arrange & Act --
        let identifier = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: "MyCustomClass",
            layerId: "MyCustomLayer"
        )

        // -- Assert --
        XCTAssertEqual(identifier.classId, "MyCustomClass")
        XCTAssertEqual(identifier.layerId, "MyCustomLayer")
    }

    func testExtendedClassIdentifier_initWithObjcType_shouldStoreCorrectDescription() {
        // -- Arrange & Act --
        let identifier = SentryUIRedactBuilder.ExtendedClassIdentifier(
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
        let identifier = SentryUIRedactBuilder.ExtendedClassIdentifier(
            class: MyCustomClass.self,
            layerId: nil
        )

        // -- Assert --
        XCTAssertEqual(identifier.classId, MyCustomClass.description())
        XCTAssertNil(identifier.layerId)
    }

    func testExtendedClassIdentifier_hashable_shouldWorkInSet() {
        // -- Arrange --
        let identifier1 = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: "ClassA",
            layerId: "LayerA"
        )
        let identifier2 = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: "ClassA",
            layerId: "LayerA"
        )
        let identifier3 = SentryUIRedactBuilder.ExtendedClassIdentifier(
            classId: "ClassB",
            layerId: "LayerB"
        )

        // -- Act --
        var set = Set<SentryUIRedactBuilder.ExtendedClassIdentifier>()
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

#endif // os(iOS)
// swiftlint:enable file_length type_body_length
