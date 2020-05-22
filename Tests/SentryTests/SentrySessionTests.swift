import XCTest

class SentrySessionTestsSwift: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
    }
    
    func testEndSession() {
        let session = SentrySession()
        let date = currentDateProvider.date().addingTimeInterval(1)
        session.endExited(withTimestamp: date)
        
        XCTAssertEqual(1, session.duration)
        XCTAssertEqual(date, session.timestamp)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
    }
    
    func testInitAndDurationNilWhenSerialize() {
        let session = SentrySession()
        session.setInit(nil)
        
        let date = currentDateProvider.date()
        session.endExited(withTimestamp: date.addingTimeInterval(2))
        session.duration = nil
        
        currentDateProvider.setDate(date: date.addingTimeInterval(3))
        let sessionSerialized = session.serialize()
        XCTAssertEqual(2, sessionSerialized["duration"] as! Double)
    }
}
