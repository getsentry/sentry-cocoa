#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
import Foundation
import SentryTestUtils
import UIKit
import XCTest

/// Reproduction for https://github.com/getsentry/sentry-cocoa/issues/7810
///
/// Session Replay crashes with `-[NSConcreteValue doubleValue]: unrecognized selector`
/// inside `SentryUIRedactBuilder.mapRedactRegion`. The crash originates from Core Animation
/// while `mapRedactRegion` walks the layer tree via `layer.sublayers`: resolving the
/// presentation layer of a layer that has an active `CABasicAnimation` whose value is a
/// boxed struct (`NSConcreteValue` wrapping `CGRect`/`CGPoint`/`CATransform3D`) makes Core
/// Animation send `doubleValue` to a value that does not respond to it, raising an
/// `NSInvalidArgumentException`.
///
/// The exception unwinds through the Swift frames of `mapRedactRegion` — which cannot catch
/// Objective-C exceptions — and force-kills the app.
///
/// These tests simulate that failure deterministically by overriding `CALayer.sublayers`
/// to raise the exact `NSInvalidArgumentException` at the crash site.
///
/// See `SentryUIRedactBuilderTests.swift` for more information on how to print the internal
/// view hierarchy of a view.
class SentryUIRedactBuilderTests_LayerTraversalCrash: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name

    /// A `CALayer` whose `sublayers` getter raises the same `NSInvalidArgumentException`
    /// that Core Animation raises when interpolating a struct-valued animation as a scalar.
    private final class ThrowingSublayersLayer: CALayer {
        override var sublayers: [CALayer]? {
            get {
                NSException(
                    name: .invalidArgumentException,
                    reason: "-[NSConcreteValue doubleValue]: unrecognized selector sent to instance 0x12e68f150",
                    userInfo: nil
                ).raise()
                return nil
            }
            set {
                // No-op: this layer never exposes sublayers, it only crashes on read.
            }
        }
    }

    /// A plain `UIView` backed by ``ThrowingSublayersLayer`` so that traversing its layer
    /// subtree reproduces the crash. It intentionally is not text/image content, so it is
    /// neither redacted nor ignored on its own merits.
    private final class ThrowingSublayersView: UIView {
        override class var layerClass: AnyClass { ThrowingSublayersLayer.self }
    }

    private func getSut(maskAllText: Bool, maskAllImages: Bool) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages
        ))
    }

    func testTryBlock_whenExceptionIsCaught_shouldLogWarning() throws {
        // -- Arrange --
        let logOutput = TestLogOutput(logsToConsole: false)
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .warning)
        defer { clearTestState() }

        let exception = NSException(
            name: .invalidArgumentException,
            reason: "-[NSConcreteValue doubleValue]: unrecognized selector sent to instance 0x12e68f150",
            userInfo: nil
        )

        // -- Act --
        let result = SentryObjCExceptionHelper.tryBlock {
            exception.raise()
        }

        // -- Assert --
        XCTAssertFalse(result)
        let loggedMessage = try XCTUnwrap(logOutput.loggedMessages.first)
        XCTAssertTrue(loggedMessage.contains("[warning]"))
        XCTAssertTrue(loggedMessage.contains("Caught Objective-C exception NSInvalidArgumentException"))
        XCTAssertTrue(loggedMessage.contains("-[NSConcreteValue doubleValue]: unrecognized selector"))
        XCTAssertEqual(logOutput.loggedMessages.count, 1, "Should log exactly one warning for the caught exception")
    }

    func testRedactRegionsFor_whenSublayersAccessThrows_shouldNotCrash() throws {
        // -- Arrange --
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        // A label that must still be redacted even though a sibling subtree crashes.
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        label.text = "Secret Text"
        label.textColor = .purple
        rootView.addSubview(label)

        // A view whose layer raises when its sublayers are accessed, mimicking the
        // Core Animation crash during a running struct-valued animation.
        let throwingView = ThrowingSublayersView(frame: CGRect(x: 0, y: 40, width: 100, height: 40))
        rootView.addSubview(throwingView)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x...; frame = (0 0; 100 100); layer = <CALayer: 0x...>>
        //   | <UILabel: 0x...; frame = (10 10; 80 20); layer = <_UILabelLayer: 0x...>>
        //   | <ThrowingSublayersView: 0x...; frame = (0 40; 100 40); layer = <ThrowingSublayersLayer: 0x...>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Traversal of the throwing subtree must not crash. Because we cannot inspect the subtree
        // to decide what needs redacting, we redact its whole bounds to avoid leaking unmasked
        // content. The sibling label must still be redacted on its own merits.
        let labelRegions = result.filter { $0.type == .redact && $0.color == UIColor.purple }
        XCTAssertEqual(labelRegions.count, 1, "Sibling label should still be redacted despite the crashing subtree")

        let labelRegion = try XCTUnwrap(labelRegions.first)
        XCTAssertEqual(labelRegion.size, CGSize(width: 80, height: 20))
        XCTAssertEqual(labelRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))

        // The crashing subtree is overmasked: a full-bounds redact region covers it so any
        // unreadable child content stays hidden. It carries no view color (it is layer-derived).
        let throwingRegions = result.filter { $0.type == .redact && $0.size == CGSize(width: 100, height: 40) }
        XCTAssertEqual(throwingRegions.count, 1, "Crashing subtree should be overmasked with a full-bounds redact region")
        let throwingRegion = try XCTUnwrap(throwingRegions.first)
        XCTAssertEqual(throwingRegion.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 40))
    }

    func testRedactRegionsFor_whenRootSublayersAccessThrows_shouldNotCrash() throws {
        // -- Arrange --
        // The root view itself is backed by a layer whose sublayers access throws.
        let rootView = ThrowingSublayersView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        // Should not crash. Because the root's sublayers cannot be read, we cannot inspect any
        // content, so the root's whole bounds are overmasked to avoid leaking unmasked content.
        XCTAssertEqual(result.count, 1)
        let region = try XCTUnwrap(result.first)
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.size, CGSize(width: 100, height: 100))
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
