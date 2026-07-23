#if os(iOS) && !targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
import Foundation
import SentryTestUtils
import UIKit
import XCTest

/// Real (non-simulated) reproduction for https://github.com/getsentry/sentry-cocoa/issues/7810
///
/// Unlike ``SentryUIRedactBuilderTests_LayerTraversalCrash`` — which injects the exception at
/// the crash site — this test makes Core Animation *itself* raise the
/// `-[NSConcreteValue doubleValue]: unrecognized selector` exception, reproducing the genuine
/// stack trace:
///
/// ```
/// -[CABasicAnimation applyForTime:presentationObject:modelObject:]
/// -[NSNumber(CAAnimatableValue) CA_interpolateValue:byFraction:]
/// ... doesNotRecognizeSelector on NSConcreteValue
/// ```
///
/// The mechanism: a `CABasicAnimation` with mismatched endpoint types — one an `NSNumber`
/// (scalar), the other an `NSValue` boxing a struct. When Core Animation interpolates the
/// running animation to build the presentation layer, it uses `NSNumber`'s interpolation and
/// sends `doubleValue` to the boxed struct, which does not respond.
///
/// `SentryUIRedactBuilder.redactRegionsFor` triggers this by sampling `view.layer.presentation()`
/// and then reading `layer.sublayers`, which cascades presentation-layer resolution into the
/// animated descendant.
///
/// - Note: This test requires a rendered key window and a run-loop spin so that Core Animation
///   commits the animation and produces a presentation layer. It is therefore inherently more
///   timing/OS-sensitive than the deterministic simulated test.
class SentryUIRedactBuilderTests_RealAnimationCrash: SentryUIRedactBuilderTests { // swiftlint:disable:this type_name

    private func getSut(maskAllText: Bool, maskAllImages: Bool) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages
        ))
    }

    func testRedactRegionsFor_withMismatchedTypeAnimation_reproducesCoreAnimationCrash() throws {
        // -- Arrange --
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))

        let container = UIView(frame: window.bounds)
        window.addSubview(container)

        // The label lives in its own branch so that its presentation layer is built by a
        // different `sublayers` call than the crashing one. When Core Animation raises while
        // resolving the animated branch, the fix skips only that branch and the label survives.
        let labelHost = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        container.addSubview(labelHost)

        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 20))
        label.text = "Secret Text"
        label.textColor = .purple
        labelHost.addSubview(label)

        // The animated view lives in a separate branch. Its layer carries a type-mismatched
        // animation, so building its presentation layer raises inside Core Animation.
        let animatedHost = UIView(frame: CGRect(x: 0, y: 40, width: 200, height: 100))
        container.addSubview(animatedHost)

        let animatedView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        animatedView.backgroundColor = .green
        animatedHost.addSubview(animatedView)

        // Make the window render so presentation layers exist for the whole tree.
        window.makeKeyAndVisible()

        // A CABasicAnimation whose endpoints have mismatched types:
        // - fromValue is an NSNumber (scalar) -> Core Animation uses NSNumber's interpolation
        // - toValue is an NSValue boxing a CGPoint (struct) -> `doubleValue` is sent to it
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSNumber(value: 0.0)
        animation.toValue = NSValue(cgPoint: CGPoint(x: 100, y: 100))
        animation.duration = 60
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animatedView.layer.add(animation, forKey: "sentry-repro-crash")

        // Let Core Animation commit the animation and build presentation layers.
        // Sampling mid-animation (fraction between 0 and 1) forces interpolation.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)

        // -- Assert --
        // With the fix, traversal survives the Core Animation exception and the sibling label
        // is still redacted.
        let labelRegions = result.filter { $0.type == .redact && $0.color == UIColor.purple }
        XCTAssertEqual(labelRegions.count, 1, "Label should still be redacted despite the crashing animation")

        window.isHidden = true
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
