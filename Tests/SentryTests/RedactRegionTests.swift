import Foundation
import Nimble
@testable import Sentry
import XCTest
#if os(iOS) || os(tvOS)
class RedactRegionTests: XCTestCase {
    
    func testSplitBySubtractingBottom() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red)
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 50, width: 100, height: 50))
        
        expect(result.count) == 1
        expect(result.first?.rect) == CGRect(x: 0, y: 0, width: 100, height: 50)
        expect(result.first?.color) == .red
    }
    
    func testSplitBySubtractingTop() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 0, width: 100, height: 50))
        
        expect(result.count) == 1
        expect(result.first?.rect) == CGRect(x: 0, y: 50, width: 100, height: 50)
    }
    
    func testSplitBySubtractingTopRight() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 50, y: 0, width: 50, height: 50))
        
        expect(result.count) == 2
        expect(result.first?.rect) == CGRect(x: 0, y: 50, width: 100, height: 50)
        expect(result[1].rect) == CGRect(x: 0, y: 0, width: 50, height: 50)
    }
    
    func testSplitBySubtractingBottomLeft() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 50, width: 50, height: 50))
        
        expect(result.count) == 2
        expect(result.first?.rect) == CGRect(x: 0, y: 0, width: 100, height: 50)
        expect(result[1].rect) == CGRect(x: 50, y: 50, width: 50, height: 50)
    }
    
    func testSplitBySubtractingMiddle() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 25, y: 25, width: 50, height: 50))
        
        expect(result.count) == 4
        expect(result[0].rect) == CGRect(x: 0, y: 0, width: 100, height: 25)
        expect(result[1].rect) == CGRect(x: 0, y: 75, width: 100, height: 25)
        expect(result[2].rect) == CGRect(x: 0, y: 25, width: 25, height: 50)
        expect(result[3].rect) == CGRect(x: 75, y: 25, width: 25, height: 50)
    }
    
    func testSplitBySubtractingInHalfHorizontally() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 25, width: 100, height: 50))
        
        expect(result.count) == 2
        expect(result[0].rect) == CGRect(x: 0, y: 0, width: 100, height: 25)
        expect(result[1].rect) == CGRect(x: 0, y: 75, width: 100, height: 25)
    }
    
    func testSplitBySubtractingInHalfVertically() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 25, y: 0, width: 50, height: 100))
        
        expect(result.count) == 2
        expect(result[0].rect) == CGRect(x: 0, y: 0, width: 25, height: 100)
        expect(result[1].rect) == CGRect(x: 75, y: 0, width: 25, height: 100)
    }
    
    func testSplitBySubtractingMiddleRight() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 25, y: 25, width: 100, height: 50))
        
        expect(result.count) == 3
        expect(result[0].rect) == CGRect(x: 0, y: 0, width: 100, height: 25)
        expect(result[1].rect) == CGRect(x: 0, y: 75, width: 100, height: 25)
        expect(result[2].rect) == CGRect(x: 0, y: 25, width: 25, height: 50)
    }
    
    func testSplitBySubtractingMiddleLeft() {
        let sut = RedactRegion(rect: CGRect(x: 50, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 25, width: 100, height: 50))
        
        expect(result.count) == 3
        expect(result[0].rect) == CGRect(x: 50, y: 0, width: 100, height: 25)
        expect(result[1].rect) == CGRect(x: 50, y: 75, width: 100, height: 25)
        expect(result[2].rect) == CGRect(x: 100, y: 25, width: 50, height: 50)
    }
    
    func testSplitBySubtracting_BottomIsWider() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red) 
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 50, width: 150, height: 50))
        
        expect(result.count) == 1
        expect(result.first?.rect) == CGRect(x: 0, y: 0, width: 100, height: 50)
        expect(result.first?.color) == .red
    }
    
}
#endif
