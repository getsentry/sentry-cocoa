import SwiftUI
import XCTest

class SentryNSDataTrackerTests: XCTestCase {

    private class Fixture {
        
        let filePath = "Some Path"
        let sentryPath = "/io.sentry/envelope.data"
        let tracker = SentryPerformanceTracker()
        let dateProvider = TestCurrentDateProvider()
        let data = "SOME DATA".data(using: .utf8)!
        
        func getSut() -> SentryNSDataTracker {
            let result = SentryNSDataTracker.sharedInstance
            Dynamic(result).tracker = self.tracker
            CurrentDate.setCurrentDateProvider(dateProvider)
            return SentryNSDataTracker.sharedInstance
        }
        
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testWritePathAtomically() {
        let sut = fixture.getSut()
        var methodPath: String?
        var methodAuxiliareFile: Bool?
        
        var result = sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false) { path, useAuxiliareFile in
            methodPath = path
            methodAuxiliareFile = useAuxiliareFile
            return false
        }
       
        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertFalse(methodAuxiliareFile!)
        XCTAssertFalse(result)
        
        result = sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: true) { _, useAuxiliareFile in
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
        
        try! sut.measure(fixture.data, writeToFile: fixture.filePath, options: .atomic) { path, writingOption, _ in
            methodPath = path
            methodOptions = writingOption
            return true
        }
        
        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertEqual(methodOptions, .atomic)
               
        do {
            try sut.measure(fixture.data, writeToFile: fixture.filePath, options: .withoutOverwriting) { _, writingOption, errorPointer in
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
    
    func testWriteAtomically_CheckTrace() {
        let sut = fixture.getSut()
        var span: Span?
                
        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false) { _, _ in
            span = self.firstSpan(tracker: self.fixture.tracker)
            XCTAssertFalse(span!.isFinished)
            self.advanceTime(bySeconds: 4)
            return true
        }
        
        assertSpanDuration(span: span!, expectedDuration: 4)
        XCTAssertTrue(span!.isFinished)
        XCTAssertEqual(span?.data?["length"] as! Int, fixture.data.count)
        XCTAssertNotNil(span)
    }
    
    func testWriteWithOptionsAndError_CheckTrace() {
        let sut = fixture.getSut()
        var span: Span?
        
        try! sut.measure(fixture.data, writeToFile: fixture.filePath, options: .atomic) { _, _, _ in
            span = self.firstSpan(tracker: self.fixture.tracker)
            XCTAssertFalse(span!.isFinished)
            self.advanceTime(bySeconds: 3)
            return true
        }
        
        assertSpanDuration(span: span!, expectedDuration: 3)
        XCTAssertTrue(span!.isFinished)
        XCTAssertEqual(span?.data?["length"] as! Int, fixture.data.count)
        XCTAssertNotNil(span)
    }
    
    func testDontTrackSentryFiles() {
        let sut = fixture.getSut()
        var span: Span?
        
        let expect = expectation(description: "")
        try! sut.measure(fixture.data, writeToFile: fixture.sentryPath, options: .atomic) { _, _, _ in
            span = self.firstSpan(tracker: self.fixture.tracker)
            expect.fulfill()
            return true
        }
        
        XCTAssertNil(span)
        wait(for: [expect], timeout: 0.1)
    }
    
    private func firstSpan(tracker: SentryPerformanceTracker) -> Span? {
        let result = Dynamic(tracker).spans as [SpanId: Span]?
        return result!.first?.value
    }
    
    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) {
        let duration = span.timestamp!.timeIntervalSince(span.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }
}
