import XCTest
@testable import Sentry

class SentryCurrentDateTests: XCTestCase {
    
    override func tearDown() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider())
    }

    func testDefaultCurrentDateProvider()  {
        let expected = Date.init()
        
        let actual =  CurrentDate.date()
        
        XCTAssertEqual(expected.timeIntervalSinceReferenceDate,
                       actual.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }
    
    func testTestCurrentDateProvider() {
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
        let expected = Date.init(timeIntervalSinceReferenceDate: 0)
        
        let actual = CurrentDate.date()
        
        XCTAssertEqual(expected, actual)
    }
}
