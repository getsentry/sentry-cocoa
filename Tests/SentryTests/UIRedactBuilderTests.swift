#if os(iOS)
import Foundation
@testable import Sentry
import UIKit
import XCTest

class UIRedactBuilderTests: XCTestCase {
    
    private class RedactOptions: SentryRedactOptions {
        var redactAllText: Bool
        var redactAllImages: Bool
        
        init(redactAllText: Bool = true, redactAllImages: Bool = true) {
            self.redactAllText = redactAllText
            self.redactAllImages = redactAllImages
        }
    }
    
    private let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    func testNoNeedForRedact() {
        let sut = UIRedactBuilder()
        rootView.addSubview(UIView(frame: CGRect(x: 20, y: 20, width: 40, height: 40)))
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactALabel() {
        let sut = UIRedactBuilder()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.color, .purple)
        XCTAssertEqual(result.first?.rect, CGRect(x: 20, y: 20, width: 40, height: 40))
    }
    
    func testDontRedactALabelOptionDisabled() {
        let sut = UIRedactBuilder()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.textColor = .purple
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions(redactAllText: false))
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactAImage() {
        let sut = UIRedactBuilder()
        
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result.first?.color)
        XCTAssertEqual(result.first?.rect, CGRect(x: 20, y: 20, width: 40, height: 40))
    }
    
    func testDontRedactAImageOptionDisabled() {
        let sut = UIRedactBuilder()
        
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions(redactAllImages: false))
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactABundleImage() {
        //The check for bundled image only works for iOS 16 and above
        //For others versions all images will be redacted
        guard #available(iOS 16, *) else { return }
        let sut = UIRedactBuilder()
        
        let imageView = UIImageView(image: .add)
        imageView.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        rootView.addSubview(imageView)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactAHiddenView() {
        let sut = UIRedactBuilder()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.isHidden = true
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactATransparentView() {
        let sut = UIRedactBuilder()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        label.alpha = 0
        rootView.addSubview(label)
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testDontRedactALabelBehindAOpaqueView() {
        let sut = UIRedactBuilder()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)
        let topView = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        topView.backgroundColor = .white
        rootView.addSubview(topView)
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedactALabelBehindATransparentView() {
        let sut = UIRedactBuilder()
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        rootView.addSubview(label)
        let topView = UIView(frame: CGRect(x: 10, y: 10, width: 60, height: 60))
        topView.backgroundColor = .clear
        rootView.addSubview(topView)
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        XCTAssertEqual(result.count, 1)
    }
    
    func testIgnoreClasses() {
        class AnotherLabel: UILabel {
        }
        
        let sut = UIRedactBuilder()
        sut.ignoreClasses.append(AnotherLabel.self)
        rootView.addSubview(AnotherLabel(frame: CGRect(x: 20, y: 20, width: 40, height: 40)))
        
        let result = sut.redactRegionsFor(view: rootView, options: RedactOptions())
        XCTAssertEqual(result.count, 0)
    }
    
}

#endif
