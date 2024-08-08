import SentryTestUtils
import XCTest

class SentryNSNotificationCenterWrapperTests: XCTestCase {
    
    private var sut: SentryNSNotificationCenterWrapper!
    
    private var didBecomeActiveExpectation: XCTestExpectation!
    private var willResignActiveExpectation: XCTestExpectation!
    
    private let didBecomeActiveNotification = SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName
    private let willResignActiveNotification = SentryNSNotificationCenterWrapper.willResignActiveNotificationName
    
    override func setUp() {
        super.setUp()
        
        sut = SentryNSNotificationCenterWrapper()
    }
    
    override func tearDown() {
        sut.removeObserver(self)
        
        super.tearDown()
    }
    
    func testAddObserver() {
        addDefaultExpectations()
        sut.addObserver(self, selector: #selector(didBecomeActive), name: didBecomeActiveNotification)
        
        NotificationCenter.default.post(Notification(name: didBecomeActiveNotification))
        
        wait(for: [didBecomeActiveExpectation, willResignActiveExpectation], timeout: 0.5)
    }
    
    func testAddObserverWithBlock() {
        let exp = expectation(description: "received notification block callback")
        var observer: NSObject?
        observer = sut.addObserver(forName: didBecomeActiveNotification, object: nil, queue: nil) { _ in
            do {
                self.sut.removeObserver(try XCTUnwrap(observer))
            } catch {
                XCTFail("notification observer was not correctly retained")
            }
            exp.fulfill()
        } as? NSObject
        NotificationCenter.default.post(.init(name: didBecomeActiveNotification))
        wait(for: [exp], timeout: 0.5)
    }
    
    func testRemoveSpecificObserver() {
        addDefaultExpectations()
        sut.addObserver(self, selector: #selector(didBecomeActive), name: didBecomeActiveNotification)
        sut.addObserver(self, selector: #selector(willResignActive), name: willResignActiveNotification)
        
        sut.removeObserver(self, name: willResignActiveNotification)
        NotificationCenter.default.post(Notification(name: didBecomeActiveNotification))
        
        wait(for: [didBecomeActiveExpectation, willResignActiveExpectation], timeout: 0.5)
    }
    
    func testRemoveObserver() {
        addDefaultExpectations()
        didBecomeActiveExpectation.isInverted = true
        
        sut.addObserver(self, selector: #selector(didBecomeActive), name: didBecomeActiveNotification)
        sut.addObserver(self, selector: #selector(willResignActive), name: willResignActiveNotification)
        
        sut.removeObserver(self)
        NotificationCenter.default.post(Notification(name: didBecomeActiveNotification))
        
        wait(for: [didBecomeActiveExpectation, willResignActiveExpectation], timeout: 0.5)
    }

    func testPostNotificationsOnMock() {
        addDefaultExpectations()
        let sut = TestNSNotificationCenterWrapper()
        sut.addObserver(self, selector: #selector(didBecomeActive), name: didBecomeActiveNotification)
        sut.post(Notification(name: didBecomeActiveNotification))
        wait(for: [didBecomeActiveExpectation, willResignActiveExpectation], timeout: 0.5)
    }
}

@objc private extension SentryNSNotificationCenterWrapperTests {
    func didBecomeActive() {
        didBecomeActiveExpectation.fulfill()
    }
    
    func willResignActive() {
        willResignActiveExpectation.fulfill()
    }
    
    func addDefaultExpectations() {
        didBecomeActiveExpectation = expectation(description: "didBecomeActive")
        willResignActiveExpectation = expectation(description: "willResignActive")
        willResignActiveExpectation.isInverted = true
    }
}
