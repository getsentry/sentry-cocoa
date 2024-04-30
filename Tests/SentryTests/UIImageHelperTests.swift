#if canImport(UIKit)
import Foundation
import Nimble
@testable import Sentry
import XCTest

class UIImageHelperTests: XCTestCase {
    
    private let testFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    
    func testAverageColorRed() {
            let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
                UIColor.red.setFill()
                context.fill(testFrame)
            }
            
            expect(UIImageHelper.averageColor(of: image, at: self.testFrame)) == .red
    }
    
    func testAverageColorGreen() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.green.setFill()
            context.fill(testFrame)
        }
        
        expect(UIImageHelper.averageColor(of: image, at: self.testFrame)) == .green
    }
    
    func testAverageColorBlue() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.blue.setFill()
            context.fill(testFrame)
        }
        
        expect(UIImageHelper.averageColor(of: image, at: self.testFrame)) == .blue
    }
    
    func testAverageColorYellow() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.yellow.setFill()
            context.fill(testFrame)
        }
        
        expect(UIImageHelper.averageColor(of: image, at: self.testFrame)) == .yellow
    }
    
    func testGreenAreaInARedImage() {
        let focusArea = CGRect(x: 25, y: 25, width: 50, height: 50)
        
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.red.setFill()
            context.fill(testFrame)
            UIColor.green.setFill()
            context.fill(focusArea)
        }
        
        expect(UIImageHelper.averageColor(of: image, at: focusArea)) == .green
    }
    
    func testHalfRedHalfGreen() {
        let image = UIGraphicsImageRenderer(size: testFrame.size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
            UIColor.green.setFill()
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        }
        
        let averageColor = UIImageHelper.averageColor(of: image, at: self.testFrame)
        let components = averageColor.cgColor.components!
        
        //Making it an int to avoid float rounding problems
        expect(Int(components[0] * 100)) == 50
        expect(Int(components[1] * 100)) == 50
        expect(components[2]) == 0
        expect(components[3]) == 1
    }
    
}

#endif
