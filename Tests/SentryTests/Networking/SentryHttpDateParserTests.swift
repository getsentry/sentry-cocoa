@testable import Sentry
import XCTest

class SentryHttpDateParserTests: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: HttpDateParser!

    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        sut = HttpDateParser()
    }

    func testDefaultDate() {
        let expected = currentDateProvider.date()
        let httpDateAsString = HttpDateFormatter.string(from: expected)
        let actual = sut.date(from: httpDateAsString)
        
        XCTAssertEqual(expected, actual)
    }

    // Even if we don't run this test below OSX 10.12 we expect the actual
    // implementation to be thread safe.
    @available(OSX 10.12, *)
    func testWithMultipleWorkItemsInParallel() {
        let queue1 = DispatchQueue(label: "SentryHttpDateParserTests1", qos: .utility, attributes: [.concurrent, .initiallyInactive])
        let queue2 = DispatchQueue(label: "SentryHttpDateParserTests2", qos: .utility, attributes: [.concurrent, .initiallyInactive])
        
        let group = DispatchGroup()
        for i in Array(0...1_000) {
            startWorkItemTest(i: i, queue: queue1, group: group)
            startWorkItemTest(i: i, queue: queue2, group: group)
        }
        
        queue1.activate()
        queue2.activate()
        group.wait()
    }
    
    func startWorkItemTest(i: Int, queue: DispatchQueue, group: DispatchGroup) {
        group.enter()
        queue.async {
            let expected = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))
            let httpDateAsString = HttpDateFormatter.string(from: expected)
            let actual = self.sut.date(from: httpDateAsString)
            
            XCTAssertEqual(expected, actual)
            group.leave()
        }
    }
}
