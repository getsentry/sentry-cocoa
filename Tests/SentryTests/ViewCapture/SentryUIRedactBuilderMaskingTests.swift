#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
import UIKit
import XCTest

private final class MaskedContainerView: UIView {}
private final class MaskedContentView: UIView {}

final class SentryUIRedactBuilderMaskingTests: XCTestCase {

    func testIsViewMaskedForTextExtraction_whenMaskAllTextEnabled_shouldReturnTrue() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: true,
            maskAllImages: false
        ))
        let view = UIView()

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenViewExplicitlyMasked_shouldReturnTrue() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false
        ))
        let view = UIView()
        SentryRedactViewHelper.maskView(view)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenAncestorExplicitlyMasked_shouldReturnTrue() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false
        ))
        let ancestor = UIView()
        let container = UIView()
        let view = UIView()
        ancestor.addSubview(container)
        container.addSubview(view)
        SentryRedactViewHelper.maskView(ancestor)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenAncestorClassMasked_shouldReturnTrue() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [MaskedContainerView.self]
        ))
        let ancestor = MaskedContainerView()
        let view = UIView()
        ancestor.addSubview(view)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenAncestorExplicitlyUnmasked_shouldReturnFalse() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [MaskedContentView.self]
        ))
        let ancestor = UIView()
        let view = MaskedContentView()
        ancestor.addSubview(view)
        SentryRedactViewHelper.unmaskView(ancestor)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsViewMaskedForTextExtraction_whenExplicitMaskInsideUnmaskedAncestor_shouldReturnTrue() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false
        ))
        let ancestor = UIView()
        let view = UIView()
        ancestor.addSubview(view)
        SentryRedactViewHelper.unmaskView(ancestor)
        SentryRedactViewHelper.maskView(view)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenUnmaskInsideMaskedAncestor_shouldReturnTrue() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false
        ))
        let ancestor = UIView()
        let view = UIView()
        ancestor.addSubview(view)
        SentryRedactViewHelper.maskView(ancestor)
        SentryRedactViewHelper.unmaskView(view)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenAncestorClassUnmasked_shouldNotPropagate() {
        // -- Arrange --
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [MaskedContentView.self],
            unmaskedViewClasses: [MaskedContainerView.self]
        ))
        let ancestor = MaskedContainerView()
        let view = MaskedContentView()
        ancestor.addSubview(view)

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenAncestorSubtreeExcluded_shouldReturnTrue() {
        // -- Arrange --
        let ancestor = MaskedContainerView()
        let view = UIView()
        ancestor.addSubview(view)
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            excludedViewClasses: [type(of: ancestor).description()]
        ))

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsViewMaskedForTextExtraction_whenExcludedAncestorExplicitlyUnmasked_shouldReturnFalse() {
        // -- Arrange --
        let ancestor = MaskedContainerView()
        let view = UIView()
        ancestor.addSubview(view)
        SentryRedactViewHelper.unmaskView(ancestor)
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            excludedViewClasses: [type(of: ancestor).description()]
        ))

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsViewMaskedForTextExtraction_whenExcludedUnmaskedViewHasMaskedAncestor_shouldReturnTrue() {
        // -- Arrange --
        let ancestor = UIView()
        let excludedView = MaskedContainerView()
        let view = UIView()
        ancestor.addSubview(excludedView)
        excludedView.addSubview(view)
        SentryRedactViewHelper.maskView(ancestor)
        SentryRedactViewHelper.unmaskView(excludedView)
        let sut = SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: false,
            maskAllImages: false,
            excludedViewClasses: [type(of: excludedView).description()]
        ))

        // -- Act --
        let result = sut.isViewMaskedForTextExtraction(view)

        // -- Assert --
        XCTAssertTrue(result)
    }
}
#endif
