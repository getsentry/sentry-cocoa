import Foundation
@testable import Sentry
import XCTest
#if os(iOS) || os(tvOS)
class RedactRegionTests: XCTestCase {
    
    func testSplitBySubtractingBottom() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red)
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 50, width: 100, height: 50))
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rect, CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(result.first?.color, .red)
    }
    
    func testSplitBySubtractingTop() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 0, width: 100, height: 50))
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rect, CGRect(x: 0, y: 50, width: 100, height: 50))
    }
    
    func testSplitBySubtractingTopRight() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 50, y: 0, width: 50, height: 50))
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.rect, CGRect(x: 0, y: 50, width: 100, height: 50))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 0, y: 0, width: 50, height: 50))
    }
    
    func testSplitBySubtractingBottomLeft() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 50, width: 50, height: 50))
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.rect, CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 50, y: 50, width: 50, height: 50))
    }
    
    func testSplitBySubtractingMiddle() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 25, y: 25, width: 50, height: 50))
        
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(try XCTUnwrap(result.first).rect, CGRect(x: 0, y: 0, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 0, y: 75, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 2)).rect, CGRect(x: 0, y: 25, width: 25, height: 50))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 3)).rect, CGRect(x: 75, y: 25, width: 25, height: 50))
    }
    
    func testSplitBySubtractingInHalfHorizontally() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 25, width: 100, height: 50))
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(try XCTUnwrap(result.first).rect, CGRect(x: 0, y: 0, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 0, y: 75, width: 100, height: 25))
    }
    
    func testSplitBySubtractingInHalfVertically() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 25, y: 0, width: 50, height: 100))
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(try XCTUnwrap(result.first).rect, CGRect(x: 0, y: 0, width: 25, height: 100))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 75, y: 0, width: 25, height: 100))
    }
    
    func testSplitBySubtractingMiddleRight() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 25, y: 25, width: 100, height: 50))
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(try XCTUnwrap(result.first).rect, CGRect(x: 0, y: 0, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 0, y: 75, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 2)).rect, CGRect(x: 0, y: 25, width: 25, height: 50))
    }
    
    func testSplitBySubtractingMiddleLeft() {
        let sut = RedactRegion(rect: CGRect(x: 50, y: 0, width: 100, height: 100))
        
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 25, width: 100, height: 50))
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(try XCTUnwrap(result.first).rect, CGRect(x: 50, y: 0, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 1)).rect, CGRect(x: 50, y: 75, width: 100, height: 25))
        XCTAssertEqual(try XCTUnwrap(result.element(at: 2)).rect, CGRect(x: 100, y: 25, width: 50, height: 50))
    }

    func testSplitBySubtracting_TopIsWider() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red)
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 0, width: 150, height: 50))
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rect, CGRect(x: 0, y: 50, width: 100, height: 50))
        XCTAssertEqual(result.first?.color, .red)
    }
    
    func testSplitBySubtracting_BottomIsWider() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red) 
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 50, width: 150, height: 50))
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rect, CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(result.first?.color, .red)
    }
    
    func testNoResultForEqualRegion() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red)
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        XCTAssertEqual(result.count, 0)
    }

    func testNoResultForLargerRegion() {
        let sut = RedactRegion(rect: CGRect(x: 50, y: 50, width: 100, height: 100), color: .red)
        let result = sut.splitBySubtracting(region: CGRect(x: 0, y: 0, width: 200, height: 200))
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testSameRegionForOutsideOfBounds() {
        let sut = RedactRegion(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red)
        let result = sut.splitBySubtracting(region: CGRect(x: 110, y: 110, width: 200, height: 200))
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rect, sut.rect)
        XCTAssertEqual(result.first?.color, .red)
    }
    
}
#endif
