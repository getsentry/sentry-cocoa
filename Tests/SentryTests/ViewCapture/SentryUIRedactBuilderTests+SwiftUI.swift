// swiftlint:disable file_length

#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
import SwiftUI
import UIKit
import XCTest

/// Dummy CALayer subclass used to simulate iOS 26 layer-only SwiftUI rendering
/// in unit tests. The builder matches layers by `type(of:).description()`, so
/// we inject this class's name via `addRedactLayerClassIdTestOnly`.
private class DummyRedactableLayer: CALayer {}

// MARK: - Layer-Only Redaction Unit Tests

/// Tests for iOS 26+ (Liquid Glass) layer-only redaction, where SwiftUI renders
/// content as CALayer sublayers without backing UIViews.
class SentryLayerRedactionTests: SentryUIRedactBuilderTests {

    // MARK: - Helpers

    private func getSut(maskAllText: Bool = true, maskAllImages: Bool = true) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages
        ))
    }

    /// Creates a root UIView with a DummyRedactableLayer sublayer (no backing UIView),
    /// and a builder configured to redact that layer class.
    private func makeSutAndRootView(
        maskAllText: Bool = true,
        maskAllImages: Bool = true,
        sublayerFrame: CGRect = CGRect(x: 10, y: 10, width: 60, height: 20),
        rootFrame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100)
    ) -> (sut: SentryUIRedactBuilder, rootView: UIView) {
        let sut = getSut(maskAllText: maskAllText, maskAllImages: maskAllImages)
        sut.addRedactLayerClassIdTestOnly(DummyRedactableLayer.description())

        let rootView = UIView(frame: rootFrame)
        let sublayer = DummyRedactableLayer()
        sublayer.frame = sublayerFrame
        rootView.layer.addSublayer(sublayer)

        return (sut, rootView)
    }

    // MARK: - Initialization: base64-encoded layer classes decoded correctly

    func testBase64EncodedLayerClassesAreCorrectlyDecoded() throws {
        guard #available(iOS 26.0, tvOS 26.0, *) else { throw XCTSkip("Layer-only redaction requires iOS 26+") }
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let layerIds = sut.getRedactLayerClassIdsTestOnly()

        XCTAssertTrue(
            layerIds.contains("_TtC7SwiftUIP33_863CCF9D49B535DAEB1C7D61BEE53B5914CGDrawingLayer"),
            "CGDrawingLayer should be registered for text masking"
        )
        XCTAssertTrue(
            layerIds.contains("SwiftUI.ImageLayer"),
            "SwiftUI.ImageLayer should be registered for image masking"
        )
        XCTAssertTrue(
            layerIds.contains("_TtC7SwiftUIP33_E19F490D25D5E0EC8A24903AF958E34115ColorShapeLayer"),
            "ColorShapeLayer should be registered for SF Symbol masking"
        )
    }

    func testLayerClassesNotRegistered_whenMaskAllTextDisabled() throws {
        guard #available(iOS 26.0, tvOS 26.0, *) else { throw XCTSkip("Layer-only redaction requires iOS 26+") }
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let layerIds = sut.getRedactLayerClassIdsTestOnly()

        XCTAssertFalse(
            layerIds.contains("_TtC7SwiftUIP33_863CCF9D49B535DAEB1C7D61BEE53B5914CGDrawingLayer"),
            "CGDrawingLayer should not be registered when maskAllText is false"
        )
        XCTAssertTrue(layerIds.contains("SwiftUI.ImageLayer"))
    }

    func testLayerClassesNotRegistered_whenMaskAllImagesDisabled() throws {
        guard #available(iOS 26.0, tvOS 26.0, *) else { throw XCTSkip("Layer-only redaction requires iOS 26+") }
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let layerIds = sut.getRedactLayerClassIdsTestOnly()

        XCTAssertFalse(
            layerIds.contains("SwiftUI.ImageLayer"),
            "SwiftUI.ImageLayer should not be registered when maskAllImages is false"
        )
        XCTAssertFalse(
            layerIds.contains("_TtC7SwiftUIP33_E19F490D25D5E0EC8A24903AF958E34115ColorShapeLayer"),
            "ColorShapeLayer should not be registered when maskAllImages is false"
        )
        XCTAssertTrue(layerIds.contains("_TtC7SwiftUIP33_863CCF9D49B535DAEB1C7D61BEE53B5914CGDrawingLayer"))
    }

    func testNoLayerClassesRegistered_whenBothMaskingDisabled() throws {
        guard #available(iOS 26.0, tvOS 26.0, *) else { throw XCTSkip("Layer-only redaction requires iOS 26+") }
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let layerIds = sut.getRedactLayerClassIdsTestOnly()

        XCTAssertTrue(layerIds.isEmpty, "No layer classes should be registered when all masking is disabled")
    }

    // MARK: - Layer-only redaction via mapRedactRegion

    func testRedact_layerOnlySublayer_shouldRedact() throws {
        let (sut, rootView) = makeSutAndRootView(sublayerFrame: CGRect(x: 10, y: 10, width: 80, height: 20))
        let result = sut.redactRegionsFor(view: rootView)

        let redactRegions = result.filter { $0.type == .redact }
        XCTAssertEqual(redactRegions.count, 1)
        XCTAssertEqual(redactRegions.first?.size, CGSize(width: 80, height: 20))
    }

    func testRedact_layerOnlySublayer_notRedacted_whenClassNotRegistered() {
        let sut = getSut()
        // Don't call addRedactLayerClassIdTestOnly — DummyRedactableLayer is not registered
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sublayer = DummyRedactableLayer()
        sublayer.frame = CGRect(x: 10, y: 10, width: 60, height: 20)
        rootView.layer.addSublayer(sublayer)

        let result = sut.redactRegionsFor(view: rootView)

        let redactRegions = result.filter { $0.type == .redact }
        XCTAssertEqual(redactRegions.count, 0, "Unregistered layer class should not be redacted")
    }

    // MARK: - Hidden / transparent layer-only sublayers

    func testRedact_hiddenLayerOnlySublayer_shouldNotRedact() {
        let (sut, rootView) = makeSutAndRootView()
        rootView.layer.sublayers?.last?.isHidden = true

        let result = sut.redactRegionsFor(view: rootView)

        let redactRegions = result.filter { $0.type == .redact }
        XCTAssertEqual(redactRegions.count, 0, "Hidden layer-only sublayer should not be redacted")
    }

    func testRedact_zeroOpacityLayerOnlySublayer_shouldNotRedact() {
        let (sut, rootView) = makeSutAndRootView()
        rootView.layer.sublayers?.last?.opacity = 0

        let result = sut.redactRegionsFor(view: rootView)

        let redactRegions = result.filter { $0.type == .redact }
        XCTAssertEqual(redactRegions.count, 0, "Fully transparent layer-only sublayer should not be redacted")
    }

    // MARK: - Unknown layer types should not be redacted

    func testRedact_unknownLayerOnlySublayer_shouldNotRedact() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sublayer = CALayer()
        sublayer.frame = CGRect(x: 10, y: 10, width: 60, height: 20)
        rootView.layer.addSublayer(sublayer)

        let sut = getSut()
        let result = sut.redactRegionsFor(view: rootView)

        let redactRegions = result.filter { $0.type == .redact }
        XCTAssertEqual(redactRegions.count, 0, "Unknown CALayer sublayer should not be redacted")
    }

    // MARK: - Region type is .redact (not .redactSwiftUI)

    func testRedact_layerOnlySublayer_producesRedactType_notRedactSwiftUI() {
        let (sut, rootView) = makeSutAndRootView()
        let result = sut.redactRegionsFor(view: rootView)

        let swiftUIRegions = result.filter { $0.type == .redactSwiftUI }
        let redactRegions = result.filter { $0.type == .redact }

        XCTAssertEqual(swiftUIRegions.count, 0, "Layer-only sublayers should not produce .redactSwiftUI regions")
        XCTAssertEqual(redactRegions.count, 1, "Layer-only sublayers should produce .redact regions")
    }

    // MARK: - enforceIgnore respected

    func testRedact_layerOnlySublayer_notRedacted_whenParentUnmasked() {
        let sut = getSut()
        sut.addRedactLayerClassIdTestOnly(DummyRedactableLayer.description())

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        container.sentryReplayUnmask()
        rootView.addSubview(container)

        let sublayer = DummyRedactableLayer()
        sublayer.frame = CGRect(x: 10, y: 10, width: 60, height: 20)
        container.layer.addSublayer(sublayer)

        let result = sut.redactRegionsFor(view: rootView)

        let redactRegions = result.filter { $0.type == .redact }
        XCTAssertEqual(redactRegions.count, 0, "Layer-only sublayer should not be redacted when parent is unmasked")
    }
}

// MARK: - SwiftUI Integration Tests

/// End-to-end tests verifying SwiftUI views are properly masked using real
/// UIHostingController rendering. These tests work across all iOS versions.
class SentrySwiftUIRedactionIntegrationTests: SentryUIRedactBuilderTests {

    // MARK: - Text

    func testSwiftUITextIsMasked() {
        let window = hostSwiftUIViewInWindow(
            VStack { Text("Hello SwiftUI").font(.system(size: 20)).padding(20) },
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        let sut = SentryUIRedactBuilder(options: SentryRedactDefaultOptions())
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertGreaterThanOrEqual(redactRegions.count, 1, "SwiftUI.Text should be masked")
    }

    func testSwiftUITextNotMaskedWhenTextMaskingDisabled() {
        let window = hostSwiftUIViewInWindow(
            VStack { Text("Hello SwiftUI").font(.system(size: 20)).padding(20) },
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        let options = SentryRedactDefaultOptions()
        options.maskAllText = false
        let sut = SentryUIRedactBuilder(options: options)
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertEqual(redactRegions.count, 0, "SwiftUI.Text should not be masked when maskAllText is disabled")
    }

    // MARK: - Image

    func testSwiftUIImageIsMasked() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        let window = hostSwiftUIViewInWindow(
            VStack { Image(uiImage: image) },
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        let sut = SentryUIRedactBuilder(options: SentryRedactDefaultOptions())
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertGreaterThanOrEqual(redactRegions.count, 1, "SwiftUI.Image should be masked")
    }

    func testSwiftUIImageNotMaskedWhenImageMaskingDisabled() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        let window = hostSwiftUIViewInWindow(
            VStack { Image(uiImage: image) },
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        let options = SentryRedactDefaultOptions()
        options.maskAllImages = false
        let sut = SentryUIRedactBuilder(options: options)
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertEqual(redactRegions.count, 0, "SwiftUI.Image should not be masked when maskAllImages is disabled")
    }

    // MARK: - SF Symbol

    func testSwiftUISFSymbolIsMasked() {
        let window = hostSwiftUIViewInWindow(
            VStack { Image(systemName: "star.fill").font(.system(size: 40)) },
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        let sut = SentryUIRedactBuilder(options: SentryRedactDefaultOptions())
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertGreaterThanOrEqual(redactRegions.count, 1, "SwiftUI.Image(systemName:) should be masked")
    }

    // MARK: - Label

    func testSwiftUILabelIsMasked() {
        let window = hostSwiftUIViewInWindow(
            VStack { Label("Hello SwiftUI", systemImage: "house").labelStyle(.titleAndIcon) },
            frame: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        let sut = SentryUIRedactBuilder(options: SentryRedactDefaultOptions())
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertGreaterThanOrEqual(redactRegions.count, 2, "SwiftUI.Label should mask both text and image")
    }

    // MARK: - List

    func testSwiftUIListTextIsMasked() {
        let window = hostSwiftUIViewInWindow(
            VStack {
                List {
                    Section("Section 1") { Text("Item 1") }
                    Section { Text("Item 2") }
                }
            },
            frame: CGRect(x: 0, y: 0, width: 300, height: 500)
        )

        let sut = SentryUIRedactBuilder(options: SentryRedactDefaultOptions())
        let result = sut.redactRegionsFor(view: window.rootViewController!.view!)

        let redactRegions = result.filter { $0.type == .redact || $0.type == .redactSwiftUI }
        XCTAssertGreaterThanOrEqual(redactRegions.count, 1, "SwiftUI.List text items should be masked")
    }
}
#endif
// swiftlint:enable file_length
