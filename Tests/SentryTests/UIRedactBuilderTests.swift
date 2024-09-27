#if os(iOS)
import Foundation
@testable import Sentry
import SentryTestUtils
import UIKit
import XCTest

class RedactOptions: SentryRedactOptions {
    var redactViewClasses: [AnyClass]
    var ignoreViewClasses: [AnyClass]
    var redactAllText: Bool
    var redactAllImages: Bool
    
    init(redactAllText: Bool = true, redactAllImages: Bool = true) {
        self.redactAllText = redactAllText
        self.redactAllImages = redactAllImages
        redactViewClasses = []
        ignoreViewClasses = []
    }
}

class UIRedactBuilderTests: XCTestCase {
    
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
    
    func testDontRedactALabelOptionDisabled() {
        let sut = getSut(RedactOptions(redactAllText: false))
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
        let sut = getSut(RedactOptions(redactAllImages: false))
        
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
    
    func testIgnoreView() {
        class AnotherLabel: UILabel {
        }
        
        let sut = getSut()
        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        SentrySDK.replay.ignoreView(label)
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactView() {
        class AnotherView: UIView {
        }
        
        let sut = getSut()
        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        SentrySDK.replay.redactView(view)
        rootView.addSubview(view)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 1)
    }
    
    func testIgnoreViewWithExtension() {
        class AnotherLabel: UILabel {
        }
        
        let sut = getSut()
        let label = AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.sentryReplayIgnore()
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactViewWithExtension() {
        class AnotherView: UIView {
        }
        
        let sut = getSut()
        let view = AnotherView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        view.sentryReplayRedact()
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
}

#endif
