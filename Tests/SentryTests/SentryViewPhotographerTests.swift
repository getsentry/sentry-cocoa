#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@testable import Sentry
import SentryTestUtils
import UIKit
import XCTest

class SentryViewPhotographerTests: XCTestCase {
    
    private class TestViewRenderer: ViewRenderer {
        func render(view: UIView) -> UIImage {
            UIGraphicsImageRenderer(size: view.bounds.size).image { context in
                view.layer.render(in: context.cgContext)
            }
        }
    }
    
    func sut() -> SentryViewPhotographer {
        return SentryViewPhotographer(renderer: TestViewRenderer(), redactOptions: RedactOptions())
    }
    
    private func prepare(views: [UIView], options: any SentryRedactOptions = RedactOptions()) -> UIImage? {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        rootView.backgroundColor = .white
        views.forEach(rootView.addSubview(_:))
        
        let sut = sut()
        let expect = expectation(description: "Image rendered")
        var result: UIImage?
             
        sut.image(view: rootView, options: options) { image in
            result = image
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 1)
        return result
    }
    
    func testLabelRedacted() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        label.text = "Test"
        
        let image = try XCTUnwrap(prepare(views: [label]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel, .black)
    }
    
    func testLabelNotRedactedWithOpaqueViewOnTop() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        label.text = "Test"
        let viewOnTop = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        viewOnTop.backgroundColor = .green
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel, .green)
    }
    
    func testLabelNotRedactedWithTwoOpaqueViewsOnTop() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        label.text = "Test"
        let viewOnTop1 = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        viewOnTop1.backgroundColor = .red
        
        let viewOnTop2 = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        viewOnTop2.backgroundColor = .green
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop1, viewOnTop2]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel, .green)
    }
    
    func testLabelRedactedWithHigherZpotition() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        label.text = "Test"
        label.layer.zPosition = 1
        
        let viewOnTop = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        viewOnTop.backgroundColor = .green
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel, .black)
    }
    
    func testLabelRedactedWithNonOpaqueViewOnTop() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        label.text = "Test"
        let viewOnTop = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        viewOnTop.backgroundColor = .red
        viewOnTop.alpha = 0.5
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel, .black)
    }
    
    func testLabelRedactedWithViewOnTopTransparentBackground() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        label.text = "Test"
        let viewOnTop = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        viewOnTop.backgroundColor = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 0.8)
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel, .black)
    }
    
    func testClipPartOfLabel() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        label.text = "Test"
        let viewOnTop = UIView(frame: CGRect(x: 20, y: 0, width: 20, height: 50))
        viewOnTop.backgroundColor = .green
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop]))
        let pixel1 = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel1, .black)
        
        let pixel2 = color(at: CGPoint(x: 22, y: 10), in: image)
        assertColor(pixel2, .green)
    }
    
    func testClipPartOfLabelTopTransformed() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        label.text = "Test"
        let viewOnTop = UIView(frame: CGRect(x: 0, y: 15, width: 50, height: 20))
        viewOnTop.backgroundColor = .green
        viewOnTop.transform = CGAffineTransform(rotationAngle: 90 * .pi / 180.0)
        
        let image = try XCTUnwrap(prepare(views: [label, viewOnTop]))
        let pixel1 = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel1, .black)
        
        let pixel2 = color(at: CGPoint(x: 22, y: 10), in: image)
        assertColor(pixel2, .green)
    }
    
    func testDontRedactClippedLabel() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 25, width: 50, height: 25))
        label.text = "Test"
        
        let labelParent = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 25))
        labelParent.backgroundColor = .green
        labelParent.clipsToBounds = true
        labelParent.addSubview(label)
        
        let image = try XCTUnwrap(prepare(views: [labelParent]))
        let pixel1 = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel1, .green)
        
        let pixel2 = color(at: CGPoint(x: 10, y: 30), in: image)
        assertColor(pixel2, .white)
    }
    
    func testRedactLabelInsideClippedView() throws {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 25))
        label.text = "Test"
        
        let labelParent = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 25))
        labelParent.backgroundColor = .green
        labelParent.clipsToBounds = true
        labelParent.addSubview(label)
        
        let image = try XCTUnwrap(prepare(views: [labelParent]))
        let pixel1 = color(at: CGPoint(x: 10, y: 10), in: image)
        
        assertColor(pixel1, .black)
        
        let pixel2 = color(at: CGPoint(x: 10, y: 30), in: image)
        assertColor(pixel2, .white)
    }
    
    private func assertColor(_ color1: UIColor, _ color2: UIColor) {
        let sRGBColor1 = color1.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)
        let sRGBColor2 = color2.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)

        XCTAssertEqual(sRGBColor1, sRGBColor2)
    }
    
    private func color(at point: CGPoint, in image: UIImage) -> UIColor {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            return .clear
        }

        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let pixelOffset = Int(point.y) * bytesPerRow + Int(point.x) * bytesPerPixel
        
        let red = CGFloat(data[pixelOffset]) / 255.0
        let green = CGFloat(data[pixelOffset + 1]) / 255.0
        let blue = CGFloat(data[pixelOffset + 2]) / 255.0
        let alpha = CGFloat(data[pixelOffset + 3]) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

#endif
