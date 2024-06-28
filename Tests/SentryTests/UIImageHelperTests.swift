#if canImport(UIKit)
import Foundation
@testable import Sentry
import XCTest

class UIImageHelperTests: XCTestCase {
    
    private let testFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    
    func testAverageColorRed() {
        let begin = Date()
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.red.setFill()
            context.fill(testFrame)
        }
        
        XCTAssertEqual(UIImageHelper.averageColor(of: image, at: self.testFrame), .red)
        
        let end = Date()
        print("Duration = \(end.timeIntervalSince(begin))")
    }
    
    func testAverageColorGreen() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.green.setFill()
            context.fill(testFrame)
        }
        
        XCTAssertEqual(UIImageHelper.averageColor(of: image, at: self.testFrame), .green)
    }
    
    func testAverageColorBlue() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.blue.setFill()
            context.fill(testFrame)
        }
        
        XCTAssertEqual(UIImageHelper.averageColor(of: image, at: self.testFrame), .blue)
    }
    
    func testAverageColorYellow() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.yellow.setFill()
            context.fill(testFrame)
        }
        
        XCTAssertEqual(UIImageHelper.averageColor(of: image, at: self.testFrame), .yellow)
    }
    
    func testGreenAreaInARedImage() {
        let focusArea = CGRect(x: 25, y: 25, width: 50, height: 50)
        
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.red.setFill()
            context.fill(testFrame)
            UIColor.green.setFill()
            context.fill(focusArea)
        }
        
        XCTAssertEqual(UIImageHelper.averageColor(of: image, at: focusArea), .green)
    }
}

#endif
