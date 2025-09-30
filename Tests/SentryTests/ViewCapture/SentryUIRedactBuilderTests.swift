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

    private func getSut(_ option: TestRedactOptions = TestRedactOptions()) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: option)
    }

    override func setUp() {
        rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testNoNeedForRedact() {
        let sut = getSut()
        rootView.addSubview(UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40)))
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactALabel() {
        let sut = getSut()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.color, .purple)
        XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(result.first?.type, .redact)
        XCTAssertEqual(result.first?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
    }
    
    func testDontUseLabelTransparentColor() {
        let sut = getSut()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple.withAlphaComponent(0.5)
        rootView.addSubview(label)

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.first?.color, .purple)
    }
    
    func testDontRedactALabelOptionDisabled() {
        let sut = getSut(TestRedactOptions(maskAllText: false))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactRCTTextView() {
        let sut = getSut(TestRedactOptions(maskAllText: true))
        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
    }

    func testDoNotRedactRCTTextView() {
        let sut = getSut(TestRedactOptions(maskAllText: false))
        let textView = RCTTextView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactRCTParagraphComponentView() {
        let sut = getSut(TestRedactOptions(maskAllText: true))
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
    }
    
    func testDoNotRedactRCTParagraphComponentView() {
        let sut = getSut(TestRedactOptions(maskAllText: false))
        let textView = RCTParagraphComponentView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(textView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactRCTImageView() {
        let sut = getSut(TestRedactOptions(maskAllImages: true))
        let imageView = RCTImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
    }
    
    func testDoNotRedactRCTImageView() {
        let sut = getSut(TestRedactOptions(maskAllImages: false))
        let imageView = RCTImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactAImage() {
        let sut = getSut()
        
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result.first?.color)
        XCTAssertEqual(result.first?.size, CGSize(width: 40, height: 40))
    }
    
    func testDontRedactAImageOptionDisabled() {
        let sut = getSut(TestRedactOptions(maskAllImages: false))
        
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactABundleImage() {
        //The check for bundled image only works for iOS 16 and above
        //For others versions all images will be redacted
        guard #available(iOS 16, *) else { return }
        let sut = getSut()
        
        let imageView = UIImageView(image: .add)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactAHiddenView() {
        let sut = getSut()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.isHidden = true
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactATransparentView() {
        let sut = getSut()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.alpha = 0
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testClipForOpaqueView() {
        let opaqueView = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        opaqueView.backgroundColor = .white
        rootView.addSubview(opaqueView)
        
        let sut = getSut()
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.type, .clipOut)
        XCTAssertEqual(result.first?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 10))
    }
    
    func testRedactALabelBehindATransparentView() {
        let sut = getSut()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)
        let topView = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        topView.backgroundColor = .clear
        rootView.addSubview(topView)
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testIgnoreClasses() {
        let sut = getSut()
        sut.addIgnoreClass(UILabel.self)
        rootView.addSubview(UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40)))
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactClasses() {
        class AnotherView: UIView {
        }
        
        let sut = getSut()
        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        sut.addRedactClass(AnotherView.self)
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testRedactSubClass() {
        class AnotherView: UILabel {
        }
        
        let sut = getSut()
        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }

    func testIgnoreContainerChildView() {
        class IgnoreContainer: UIView {}
        class AnotherLabel: UILabel {}

        let sut = getSut()
        sut.setIgnoreContainerClass(IgnoreContainer.self)

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let wrappedLabel = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        ignoreContainer.addSubview(wrappedLabel)
        rootView.addSubview(ignoreContainer)

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 0)
    }

    func testIgnoreContainerDirectChildView() {
        class IgnoreContainer: UIView {}
        class AnotherLabel: UILabel {}

        let sut = getSut()
        sut.setIgnoreContainerClass(IgnoreContainer.self)

        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let wrappedLabel = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedLabel = AnotherLabel(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        wrappedLabel.addSubview(redactedLabel)
        ignoreContainer.addSubview(wrappedLabel)
        rootView.addSubview(ignoreContainer)

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }

    func testRedactIgnoreContainerAsChildOfMaskedView() {
        class IgnoreContainer: UIView {}

        let sut = getSut()
        sut.setIgnoreContainerClass(IgnoreContainer.self)

        let redactedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let ignoreContainer = IgnoreContainer(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedChildLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        ignoreContainer.addSubview(redactedChildLabel)
        redactedLabel.addSubview(ignoreContainer)
        rootView.addSubview(redactedLabel)

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 3)
    }

    func testRedactChildrenOfRedactContainer() {
        class RedactContainer: UIView {}
        class AnotherView: UIView {}

        let sut = getSut()
        sut.setRedactContainerClass(RedactContainer.self)

        let redactContainer = RedactContainer(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        let redactedView2 = AnotherView(frame: CGRect(x: 10, y: 10, width: 10, height: 10))
        redactedView.addSubview(redactedView2)
        redactContainer.addSubview(redactedView)
        rootView.addSubview(redactContainer)

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 3)
    }

    func testRedactChildrenOfRedactedView() {
        class AnotherView: UIView {}

        let sut = getSut()

        let redactedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        let redactedView = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        redactedLabel.addSubview(redactedView)
        rootView.addSubview(redactedLabel)

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 2)
    }

    func testRedactContainerHasPriorityOverIgnoreContainer() {
        class IgnoreContainer: UIView {}
        class RedactContainer: UIView {}
        class AnotherView: UIView {}

        let sut = getSut()
        sut.setRedactContainerClass(RedactContainer.self)

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

        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 4)
    }

    func testIgnoreView() {
        class AnotherLabel: UILabel {
        }
        
        let sut = getSut()
        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        SentrySDK.replay.unmaskView(label)
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactView() {
        class AnotherView: UIView {
        }
        
        let sut = getSut()
        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        SentrySDK.replay.maskView(view)
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testIgnoreViewWithExtension() {
        class AnotherLabel: UILabel {
        }
        
        let sut = getSut()
        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.sentryReplayUnmask()
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactViewWithExtension() {
        class AnotherView: UIView {
        }
        
        let sut = getSut()
        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.sentryReplayMask()
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testIgnoreViewsBeforeARootSizedView() {
        let sut = getSut()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
        let overView = UIView(frame: rootView.bounds)
        overView.backgroundColor = .black
        rootView.addSubview(overView)
        
        let result = sut.redactRegionsFor(view: rootView)
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDefaultRedactList_shouldContainAllPlatformSpecificClasses() {
        // -- Arrange --
        let expectedListClassNames = [
            // SwiftUI Views
            "_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer",
            // Web Views
            "UIWebView", "SFSafariView", "WKWebView",
            // Text Views (incl. HybridSDK)
            "UILabel", "UITextView", "UITextField", "RCTTextView", "RCTParagraphComponentView",
            // Document Views
            "PDFView",
            // Image Views (incl. HybridSDK)
            "UIImageView", "RCTImageView",
            // Audio / Video Views
            "AVPlayerView"
        ]

        let expectedList = expectedListClassNames.map { className -> (String, ObjectIdentifier?) in
            guard let classType = NSClassFromString(className) else {
                print("Class \(className) not found, skipping test")
                return (className, nil)
            }
            return (className, ObjectIdentifier(classType))
        }

        // -- Act --
        let sut = getSut()

        // -- Assert --
        // Build sets of expected and actual identifiers for comparison
        let expectedIdentifiers = Set(expectedList.compactMap { $0.1 })
        let actualIdentifiers = Set(sut.redactClassesIdentifiers)

        // Check for identifiers that are expected but missing in the actual result
        let missingIdentifiers = expectedIdentifiers.subtracting(actualIdentifiers)
        // Check for identifiers that are present in the actual result but not expected
        let unexpectedIdentifiers = actualIdentifiers.subtracting(expectedIdentifiers)

        // For each expected class, check that if we expect the class identifier to be nil, it is nil
        for (expectedClassName, expectedNullableIdentifier) in expectedList {
            if expectedNullableIdentifier == nil {
                // If we expect nil, assert that no identifier in the actual list matches the class name
                let found = sut.redactClassesIdentifiers.contains { $0.debugDescription.contains(expectedClassName) }
                XCTAssertFalse(found, "Class \(expectedClassName) not found in runtime, but it is present in the redact list")
            } else {
                // If we expect a non-nil identifier, assert that it is present in the actual list
                XCTAssertTrue(sut.redactClassesIdentifiers.contains(where: { $0 == expectedNullableIdentifier }), "Expected class \(expectedClassName) not found in redact list")
            }
        }

        // Assert that there are no missing identifiers
        XCTAssertTrue(missingIdentifiers.isEmpty, "Missing expected class identifiers: \(missingIdentifiers)")

        // Assert that there are no unexpected identifiers
        for identifier in unexpectedIdentifiers {
            // Try to get the class name from the identifier
            let classCount = objc_getClassList(nil, 0)
            var className = "<unknown>"
            if classCount > 0 {
                let classes = UnsafeMutablePointer<AnyClass?>.allocate(capacity: Int(classCount))
                defer { classes.deallocate() }
                let autoreleasingClasses = AutoreleasingUnsafeMutablePointer<AnyClass>(classes)
                let count = objc_getClassList(autoreleasingClasses, classCount)
                for i in 0..<Int(count) {
                    if let cls = classes[i], ObjectIdentifier(cls) == identifier {
                        className = NSStringFromClass(cls)
                        break
                    }
                }
            }
            XCTFail("Unexpected class identifier found: \(identifier) (\(className))")
        }
        XCTAssertTrue(unexpectedIdentifiers.isEmpty, "Unexpected class identifiers found: \(unexpectedIdentifiers)")

        // Assert that the sets are equal (final check)
        XCTAssertEqual(actualIdentifiers, expectedIdentifiers, "Mismatch between expected and actual class identifiers")
    }
    
    func testIgnoreList() {
        let expectedList = ["UISlider", "UISwitch"].compactMap { NSClassFromString($0) }
        
        let sut = getSut()
        expectedList.forEach { element in
            XCTAssertTrue(sut.containsIgnoreClass(element), "\(element) not found")
        }
    }
    
    func testLayerIsNotFullyTransparentRedacted() {
        let sut = getSut()
        let view = CustomVisibilityView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.alpha = 0
        view.sentryReplayMask()
        
        view.backgroundColor = .purple
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testViewLayerOnTopIsNotFullyTransparentRedacted() {
        let sut = getSut()
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
        let sut = getSut()
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
        let sut = getSut(TestRedactOptions(maskAllText: false, maskAllImages: false))
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

    func testRedactPDFView() throws {
        // -- Arrange --
        let sut = getSut()
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

    func testRedactPDFViewEvenWithMaskingDisabled() throws {
        // -- Arrange --
        // PDFView should always be redacted for security reasons,
        // regardless of maskAllText and maskAllImages settings
        let sut = getSut(TestRedactOptions(maskAllText: false, maskAllImages: false))
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

    func testPDFViewInRedactList() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act & Assert --
        XCTAssertTrue(sut.containsRedactClass(PDFView.self), "PDFView should be in the redact class list")
    }

    func testRedactAVPlayerViewController() throws {
        // -- Arrange --
        let sut = getSut()
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

    func testRedactAVPlayerViewControllerEvenWithMaskingDisabled() throws {
        // -- Arrange --
        // AVPlayerViewController should always be redacted for security reasons,
        // regardless of maskAllText and maskAllImages settings
        let sut = getSut(TestRedactOptions(maskAllText: false, maskAllImages: false))
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

    func testAVPlayerViewInRedactList() throws {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act & Assert --
        // Note: The redaction system uses "AVPlayerView" as the class name string
        // which should resolve to the internal view hierarchy of AVPlayerViewController
        guard let avPlayerViewClass = NSClassFromString("AVPlayerView") else {
            throw XCTSkip("AVPlayerView class not found, skipping test")
        }
        XCTAssertTrue(sut.containsRedactClass(avPlayerViewClass), "AVPlayerView should be in the redact class list")
    }

    func testViewSubtreeIgnored_noIgnoredViewsInTree_shouldIncludeEntireTree() {
        // -- Arrange --
        let sut = getSut()
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(view)

        let subview = UILabel(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        view.addSubview(subview)

        let subSubview = UIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
        subview.addSubview(subSubview)

        // -- Act --
        let result = sut.redactRegionsFor(view: rootView)

        // -- Assert --
        XCTAssertEqual(result.count, 2)

        XCTAssertEqual(result.element(at: 0)?.size, CGSize(width: 10, height: 10))
        XCTAssertEqual(result.element(at: 0)?.type, .redact)
        XCTAssertEqual(result.element(at: 0)?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 35, ty: 35))
        XCTAssertNil(result.element(at: 0)?.color)

        XCTAssertEqual(result.element(at: 1)?.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(result.element(at: 1)?.type, .redact)
        XCTAssertEqual(result.element(at: 1)?.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 30, ty: 30))
        XCTAssertNotNil(result.element(at: 1)?.color)
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
        let sut = getSut()
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
        
        let sut = getSut()
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
        let decorationView = try createCollectionViewListBackgroundDecorationView(frame: .zero)

        // Configure a very large frame similar to what we see in production
        decorationView.frame = CGRect(x: -20, y: -1100, width: 440, height: 2300)
        decorationView.backgroundColor = .systemGroupedBackground

        // Add another redacted view that must remain redacted (no clip-out should hide it)
        let titleLabel = UILabel(frame: CGRect(x: 16, y: 60, width: 120, height: 40))
        titleLabel.text = "Flinky"

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        rootView.addSubview(decorationView)
        rootView.addSubview(titleLabel)

        let sut = getSut()

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
        let decorationView = try createCollectionViewListBackgroundDecorationView(frame: .zero)

        // Large frame similar to the debug output (-1135, 2336)
        decorationView.frame = CGRect(x: -20, y: -1135.33, width: 442, height: 2336)
        decorationView.backgroundColor = .systemGroupedBackground
        listContainer.addSubview(decorationView)

        // A representative list cell area (not strictly necessary for the bug but mirrors structure)
        let cell = UIView(frame: CGRect(x: 20, y: 0, width: 362, height: 45.33))
        cell.backgroundColor = .white
        listContainer.addSubview(cell)

        let sut = getSut()

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
        let cameraView = try createCameraUIView(frame: CGRect(x: 10, y: 10, width: 100, height: 100))
        rootView.addSubview(cameraView)

        // -- Act --
        let sut = getSut()
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
        let cameraView = try createCameraUIView(frame: CGRect(x: 10, y: 10, width: 100, height: 100))
        rootView.addSubview(cameraView)
        
        // Create a view hierarchy: root -> cameraView -> label
        // The label would normally be redacted, but since it's inside a CameraUI view that triggers
        // isViewSubtreeIgnored, the entire subtree should be redacted as one region
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 60, height: 30))
        label.text = "Test Label"
        cameraView.addSubview(label)

        // -- Act --
        let sut = getSut()
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

    /// Creates a CameraUI.ChromeSwiftUIView instance for testing isViewSubtreeIgnored functionality.
    /// - Parameters:
    ///   - frame: The frame to set for the created view
    /// - Returns: The created CameraUI view
    /// - Throws: XCTSkip if CameraUI is not available, or other errors if creation fails
    private func createCameraUIView(frame: CGRect) throws -> UIView {
        // Load the private framework indirectly by creating an instance of UIImagePickerController
        let _ = UIImagePickerController()

        // Get the CameraUI.ChromeSwiftUIView class
        let cameraViewClass: AnyClass
        if #available(iOS 26.0, *) {
            cameraViewClass = try XCTUnwrap(
                NSClassFromString("CameraUI.ChromeSwiftUIView"), 
                "Test case expects the CameraUI.ChromeSwiftUIView class to exist"
            )
        } else {
            throw XCTSkip("Type CameraUI.ChromeSwiftUIView is not available on this platform")
        }

        // Create an instance of the CameraUI view
        let cameraView = try XCTUnwrap(class_createInstance(cameraViewClass, 0) as? UIView)

        // Reinitialize storage using UIView.initWithFrame(_:)
        typealias InitWithFrame = @convention(c) (AnyObject, Selector, CGRect) -> AnyObject
        let sel = NSSelectorFromString("initWithFrame:")
        let m = try XCTUnwrap(class_getInstanceMethod(UIView.self, sel))
        let f = unsafeBitCast(method_getImplementation(m), to: InitWithFrame.self)
        _ = f(cameraView, sel, .zero)

        // Configure the view frame
        cameraView.frame = frame

        return cameraView
    }

    /// Creates a `_UICollectionViewListLayoutSectionBackgroundColorDecorationView` instance for tests.
    /// - Parameter frame: Frame to assign after allocation and storage reinitialization
    /// - Returns: The created decoration background view
    /// - Throws: `XCTSkip` if the class is not available on the platform
    private func createCollectionViewListBackgroundDecorationView(frame: CGRect) throws -> UIView {
        // Obtain class at runtime – skip if unavailable
        guard let decorationClass = NSClassFromString("_UICollectionViewListLayoutSectionBackgroundColorDecorationView") else {
            throw XCTSkip("Decoration view class not available on this platform/runtime")
        }

        // Allocate instance without calling subclass initializers
        let decorationView = try XCTUnwrap(class_createInstance(decorationClass, 0) as? UIView)

        // Reinitialize storage using UIView.initWithFrame(_:) similar to other helpers
        typealias InitWithFrame = @convention(c) (AnyObject, Selector, CGRect) -> AnyObject
        let sel = NSSelectorFromString("initWithFrame:")
        let m = try XCTUnwrap(class_getInstanceMethod(UIView.self, sel))
        let f = unsafeBitCast(method_getImplementation(m), to: InitWithFrame.self)
        _ = f(decorationView, sel, frame)

        return decorationView
    }
}

#endif // os(iOS)
