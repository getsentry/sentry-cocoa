#if os(iOS) && !targetEnvironment(macCatalyst)
import AVKit
import Foundation
import PDFKit
import SafariServices
@_spi(Private) @testable import Sentry
import SentryTestUtils
import SwiftUI
import UIKit
import WebKit
import XCTest

/*
 * Mocked RCTTextView to test the redaction of text from React Native apps.
 */
@objc(RCTTextView)
private class RCTTextView: UIView {
}

/*
 * Mocked RCTParagraphComponentView to test the redaction of text from React Native apps.
 */
@objc(RCTParagraphComponentView)
private class RCTParagraphComponentView: UIView {
}

/*
 * Mocked RCTImageView to test the redaction of images from React Native apps.
 */
@objc(RCTImageView)
private class RCTImageView: UIView {
}

/// See `SentryUIRedactBuilderTests.swift` for more information on how to print the internal view hierarchy of a view.
class SentryUIRedactBuilderTests_ReactNative: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name
    private func getSut(maskAllText: Bool, maskAllImages: Bool) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages
        ))
    }

    // MARK: - RCTTextView Redaction

    private func setupRCTTextViewFixture() -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        return rootView

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10594ea10; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce53b0>>
        //   | <RCTTextView: 0x105951d60; frame = (20 20; 40 40); layer = <CALayer: 0x600000ce6790>>
    }

    func testRedact_withRCTTextView_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = setupRCTTextViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        let region = try XCTUnwrap(result.element(at: 0))
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
        let rootView = setupRCTTextViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withRCTTextView_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let rootView = setupRCTTextViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        XCTAssertEqual(result.count, 1)
    }

    // MARK: - RCTParagraphComponentView Redaction

    private func setupRCTParagraphComponentFixture() -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)

        return rootView

        // View Hierarchy:
        // ---------------
        // <UIView: 0x11a943f30; frame = (0 0; 100 100); layer = <CALayer: 0x600000cda3d0>>
        //   | <RCTParagraphComponentView: 0x106350670; frame = (20 20; 40 40); layer = <CALayer: 0x600000cdaa60>>
    }

    func testRedact_withRCTParagraphComponent_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = setupRCTParagraphComponentFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        
        let region = try XCTUnwrap(result.element(at: 0))
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
        let rootView = setupRCTParagraphComponentFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withRCTParagraphComponent_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let rootView = setupRCTParagraphComponentFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        XCTAssertEqual(result.count, 1)
    }

    // - MARK: - RCTImageView Redaction

    private func setupRCTImageViewFixture() -> UIView {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let imageView = RCTImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(imageView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x10584f470; frame = (0 0; 100 100); layer = <CALayer: 0x600000ce8fc0>>
        //   | <RCTImageView: 0x10585e6a0; frame = (20 20; 40 40); layer = <CALayer: 0x600000cea130>>
        return rootView
    }

    func testRedact_withRCTImageView_withMaskAllImagesEnabled_shouldRedactView() throws {
        // -- Arrange --
        let rootView = setupRCTImageViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        
        let region = try XCTUnwrap(result.element(at: 0))
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
        let rootView = setupRCTImageViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withRCTImageView_withMaskAllTextDisabled_shouldRedactView() {
        // -- Arrange --
        let rootView = setupRCTImageViewFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --        XCTAssertEqual(result.count, 1)
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
