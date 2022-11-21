import XCTest

extension SentrySwizzleWrapper {
    
    static func hasItems() -> Bool {
        guard let result = Dynamic(self).hasCallbacks as Bool? else {
            return false
        }
        
        return result
    }
    
}

class SentrySwizzleWrapperTests: SentryBaseUnitTest {
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    private class Fixture {
        let actionName = #selector(someMethod).description
        let event = UIEvent()
    }
    
    private var fixture: Fixture!
    private var sut: SentrySwizzleWrapper!
    
    @objc
    func someMethod() {
        // Empty on purpose
    }
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        sut = SentrySwizzleWrapper.sharedInstance
    }

    func testSendAction_RegisterCallbacks_CallbacksCalled() {
        let firstExpectation = expectation(description: "first")
        sut.swizzleSendAction({ actualAction, _, _, actualEvent in
            XCTAssertEqual(self.fixture.actionName, actualAction)
            XCTAssertEqual(self.fixture.event, actualEvent)
            firstExpectation.fulfill()
        }, forKey: "first")
        
        let secondExpectation = expectation(description: "second")
        sut.swizzleSendAction({ actualAction, _, _, actualEvent in
            XCTAssertEqual(self.fixture.actionName, actualAction)
            XCTAssertEqual(self.fixture.event, actualEvent)
            secondExpectation.fulfill()
        }, forKey: "second")
        
        sendActionCalled()
        
        wait(for: [firstExpectation, secondExpectation], timeout: 0.1)
    }
    
    func testSendAction_RegisterCallbackForSameKey_LastCallbackCalled() {
        let firstExpectation = expectation(description: "first")
        firstExpectation.isInverted = true
        sut.swizzleSendAction({ _, _, _, _ in
            firstExpectation.fulfill()
        }, forKey: "first")
        
        let secondExpectation = expectation(description: "second")
        sut.swizzleSendAction({ actualAction, _, _, actualEvent in
            XCTAssertEqual(self.fixture.actionName, actualAction)
            XCTAssertEqual(self.fixture.event, actualEvent)
            secondExpectation.fulfill()
        }, forKey: "first")
        
        sendActionCalled()
        
        wait(for: [firstExpectation, secondExpectation], timeout: 0.1)
    }
    
    func testSendAction_RemoveCallback_CallbackNotCalled() {
        let firstExpectation = expectation(description: "first")
        firstExpectation.isInverted = true
        sut.swizzleSendAction({ _, _, _, _ in
            firstExpectation.fulfill()
        }, forKey: "first")
        
        sut.removeSwizzleSendAction(forKey: "first")
        
        sendActionCalled()
        
        wait(for: [firstExpectation], timeout: 0.1)
    }
    
    func testSendAction_AfterCallingReset_CallbackNotCalled() {
        let neverExpectation = expectation(description: "never")
        neverExpectation.isInverted = true
        sut.swizzleSendAction({ _, _, _, _ in
            neverExpectation.fulfill()
        }, forKey: "never")
        
        sut.removeAllCallbacks()
        
        sendActionCalled()
        
        wait(for: [neverExpectation], timeout: 0.1)
    }
    
    private func sendActionCalled() {
        Dynamic(SentrySwizzleWrapper.self).sendActionCalled(#selector(someMethod), target: nil, sender: nil, event: self.fixture.event)
    }

#endif
    
}
