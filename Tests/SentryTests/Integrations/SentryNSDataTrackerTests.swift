import SwiftUI
import XCTest

class SentryNSDataTrackerTests: XCTestCase {

    private class Fixture {
        
        let filePath = "Some Path"
        
        func getSut() -> SentryNSDataTracker {
            return SentryNSDataTracker.sharedInstance
        }
        
    }
    
    private let fixture = Fixture()
    
    func testWritePathAtomically() {
        let sut = fixture.getSut()
        var methodPath: String?
        var methodAuxiliareFile: Bool?
        
        var result = sut.measureWrite(toFile: fixture.filePath, atomically: false) { path, useAuxiliareFile in
            methodPath = path
            methodAuxiliareFile = useAuxiliareFile
            return false
        }
        
        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertFalse(methodAuxiliareFile!)
        XCTAssertFalse(result)
        
        result = sut.measureWrite(toFile: fixture.filePath, atomically: true) { _, useAuxiliareFile in
            methodAuxiliareFile = useAuxiliareFile
            return true
        }
        
        XCTAssertTrue(methodAuxiliareFile!)
        XCTAssertTrue(result)
    }
    
}
