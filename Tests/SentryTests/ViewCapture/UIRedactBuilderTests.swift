#if os(iOS)
import Foundation
@testable import Sentry
import SentryTestUtils
import UIKit
import XCTest

class RedactOptions: SentryRedactOptions {
    var maskedViewClasses: [AnyClass]
    var unmaskedViewClasses: [AnyClass]
    var maskAllText: Bool
    var maskAllImages: Bool

    init(maskAllText: Bool = true, maskAllImages: Bool = true) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        maskedViewClasses = []
        unmaskedViewClasses = []
    }
}

class UIRedactBuilderTests: XCTestCase {
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
    
    private let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    private func getSut(_ option: RedactOptions = RedactOptions()) -> UIRedactBuilder {
        return UIRedactBuilder(options: option)
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
        let sut = getSut(RedactOptions(maskAllText: false))
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
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
        let sut = getSut(RedactOptions(maskAllImages: false))
        
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
    
    func testRedactList() {
        let expectedList = ["_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer", "UIWebView", "UILabel", "UITextView", "UITextField", "WKWebView"
        ].compactMap { NSClassFromString($0) }
        
        let sut = getSut()
        expectedList.forEach { element in
            XCTAssertTrue(sut.containsRedactClass(element), "\(element) not found")
        }
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
}

#endif
