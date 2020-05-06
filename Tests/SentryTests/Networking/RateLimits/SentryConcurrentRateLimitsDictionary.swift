import XCTest

class SentryConcurrentRateLimitsDictionaryTests: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: SentryConcurrentRateLimitsDictionary!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        sut = SentryConcurrentRateLimitsDictionary()
    }
    
    func testOneRateLimit() {
        let date = self.currentDateProvider.date()
        self.sut.addRateLimits(["A" : date])
        XCTAssertEqual(date, self.sut.getRateLimit(forCategory: "A"))
    }
    
    func testTwoRateLimit() {
        let dateA = self.currentDateProvider.date()
        let dateB = dateA.addingTimeInterval(TimeInterval(1))
        self.sut.addRateLimits(["A" : dateA, "B": dateB])
        XCTAssertEqual(dateA, self.sut.getRateLimit(forCategory: "A"))
        XCTAssertEqual(dateB, self.sut.getRateLimit(forCategory: "B"))
    }
    
    func testOverridingRateLimit() {
        let dateA = self.currentDateProvider.date()
        let dateB = dateA.addingTimeInterval(TimeInterval(1))
        self.sut.addRateLimits(["A" : dateA])
        XCTAssertEqual(dateA, self.sut.getRateLimit(forCategory: "A"))
        self.sut.addRateLimits(["A" : dateB])
        XCTAssertEqual(dateB, self.sut.getRateLimit(forCategory: "A"))
    }

    func testConcurrentReadWrite()  {
        let queue1 = DispatchQueue(label: "SentryConcurrentRateLimitsStorageTests1", qos: .background, attributes: [.concurrent, .initiallyInactive])
        let queue2 = DispatchQueue(label: "SentryConcurrentRateLimitsStorageTests2", qos: .utility, attributes: [.concurrent, .initiallyInactive])
        
        let group = DispatchGroup()
        
        for i in Array(0...10) {
            group.enter()
            queue1.async {
                let date = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))
                self.sut.addRateLimits(["A\(i)" : date, "B\(i)" : date])
                XCTAssertEqual(date, self.sut.getRateLimit(forCategory: "A\(i)"))
                XCTAssertEqual(date, self.sut.getRateLimit(forCategory: "B\(i)"))
                group.leave()
            }
            
            group.enter()
            queue2.async {
                let date = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))
                self.sut.addRateLimits(["C\(i)" : date])
                XCTAssertEqual(date, self.sut.getRateLimit(forCategory: "C\(i)"))
                self.sut.addRateLimits(["D\(i)" : date])
                group.leave()
            }
        }
        
        queue1.activate()
        queue2.activate()
        group.wait()
        
        for i in Array(0...10) {
            let date = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))
            XCTAssertEqual(date, sut.getRateLimit(forCategory: "A\(i)"))
            XCTAssertEqual(date, sut.getRateLimit(forCategory: "B\(i)"))
            XCTAssertEqual(date, sut.getRateLimit(forCategory: "C\(i)"))
            XCTAssertEqual(date, sut.getRateLimit(forCategory: "D\(i)"))
        }
    }
}
