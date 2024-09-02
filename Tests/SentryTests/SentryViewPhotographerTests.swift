#if os(iOS)
import Foundation
@testable import Sentry
import SentryTestUtils
import UIKit
import XCTest

class SentryViewPhotographerTests : XCTestCase {
    
    private class RedactOptions : SentryRedactOptions {
        var redactAllText: Bool
        var redactAllImages: Bool
        
        init(redactAllText: Bool = true, redactAllImages: Bool = true) {
            self.redactAllText = redactAllText
            self.redactAllImages = redactAllImages
        }
    }
    
    private func prepare(views: [UIView], options: any SentryRedactOptions = RedactOptions()) -> UIImage? {
        let rootView = UIView(frame: CGRect(x:0, y: 0, width: 50, height: 50))
        rootView.backgroundColor = .white
        views.forEach(rootView.addSubview(_:))
        
        let sut = SentryViewPhotographer()
        let expect = expectation(description: "Image rendered")
        var result : UIImage? = nil
        
        sut.image(view: rootView, options: options) { image in
            result = image
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 1)
        return result
    }
    
    
    func testLabelRedacted() throws {
        let image = try XCTUnwrap(prepare(views: [UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))]))
        let pixel = color(at: CGPoint(x: 10, y: 10), in: image)
        
        XCTAssertEqual(pixel, UIColor.black)
    }
    
   
    
    private func color(at point: CGPoint, in image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            return nil
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
