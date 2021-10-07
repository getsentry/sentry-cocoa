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
    
    func testWritePathOptionsError() {
        let sut = fixture.getSut()
        var methodPath: String?
        var methodOptions: NSData.WritingOptions?
        var methodError: NSError?
        
        try! sut.measureWrite(toFile: fixture.filePath, options: .atomic) { path, writingOption, _ in
            methodPath = path
            methodOptions = writingOption
            return true
        }
        
        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertEqual(methodOptions, .atomic)
               
        do {
            try sut.measureWrite(toFile: fixture.filePath, options: .withoutOverwriting) { _, writingOption, errorPointer in
                methodOptions = writingOption
                errorPointer?.pointee = NSError(domain: "Test Error", code: -2, userInfo: nil)
                return false
            }
        } catch {
            methodError = error as NSError?
        }
        
        XCTAssertEqual(methodOptions, .withoutOverwriting)
        XCTAssertEqual(methodError?.domain, "Test Error")
    }
}
