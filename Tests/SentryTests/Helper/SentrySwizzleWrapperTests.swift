import XCTest

extension SentrySwizzleWrapper {
    
    static func hasItens() -> Bool {
        guard let result = Dynamic(self).hasCallbacks as Bool? else {
            return false
        }
        
        return result
    }
    
}

class SentrySwizzleWrapperTests: XCTestCase {
    
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
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testSendAction_RegisterCallbacks_CallbacksCalled() {
        let firstExcpectation = expectation(description: "first")
        sut.swizzleSendAction({ actualAction, _, _, actualEvent in
            XCTAssertEqual(self.fixture.actionName, actualAction)
            XCTAssertEqual(self.fixture.event, actualEvent)
            firstExcpectation.fulfill()
        }, forKey: "first")
        
        let secondExcpectation = expectation(description: "second")
        sut.swizzleSendAction({ actualAction, _, _, actualEvent in
            XCTAssertEqual(self.fixture.actionName, actualAction)
            XCTAssertEqual(self.fixture.event, actualEvent)
            secondExcpectation.fulfill()
        }, forKey: "second")
        
        sendActionCalled()
        
        wait(for: [firstExcpectation, secondExcpectation], timeout: 0.1)
    }
    
    func testSendAction_RegisterCallbackForSameKey_LastCallbackCalled() {
        let firstExcpectation = expectation(description: "first")
        firstExcpectation.isInverted = true
        sut.swizzleSendAction({ _, _, _, _ in
            firstExcpectation.fulfill()
        }, forKey: "first")
        
        let secondExcpectation = expectation(description: "second")
        sut.swizzleSendAction({ actualAction, _, _, actualEvent in
            XCTAssertEqual(self.fixture.actionName, actualAction)
            XCTAssertEqual(self.fixture.event, actualEvent)
            secondExcpectation.fulfill()
        }, forKey: "first")
        
        sendActionCalled()
        
        wait(for: [firstExcpectation, secondExcpectation], timeout: 0.1)
    }
    
    func testSendAction_RemoveCallback_CallbackNotCalled() {
        let firstExcpectation = expectation(description: "first")
        firstExcpectation.isInverted = true
        sut.swizzleSendAction({ _, _, _, _ in
            firstExcpectation.fulfill()
        }, forKey: "first")
        
        sut.removeSwizzleSendAction(forKey: "first")
        
        sendActionCalled()
        
        wait(for: [firstExcpectation], timeout: 0.1)
    }
    
    func testSendAction_AfterCallingReset_CallbackNotCalled() {
        let neverExcpectation = expectation(description: "never")
        neverExcpectation.isInverted = true
        sut.swizzleSendAction({ _, _, _, _ in
            neverExcpectation.fulfill()
        }, forKey: "never")
        
        sut.removeAllCallbacks()
        
        sendActionCalled()
        
        wait(for: [neverExcpectation], timeout: 0.1)
    }
    
    private func sendActionCalled() {
        Dynamic(SentrySwizzleWrapper.self).sendActionCalled(#selector(someMethod), target: nil, sender: nil, event: self.fixture.event)
    }

#endif
    
}
