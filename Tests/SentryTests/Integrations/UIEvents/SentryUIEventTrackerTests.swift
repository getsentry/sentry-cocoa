import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIEventTrackerTests: XCTestCase {

    private class Fixture {
        let swizzleWrapper = TestSentrySwizzleWrapper()
        
        func getSut() -> SentryUIEventTracker {
            return SentryUIEventTracker(swizzleWrapper: swizzleWrapper, dispatchQueueWrapper: SentryDispatchQueueWrapper.init())
        }
    }

    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.swizzleWrapper.removeAllCallbacks()
        clearTestState()
    }
    
    func test_Create_Transaction() {
        let sut = fixture.getSut()
        sut.start()
        callExecuteAction(sut, action: "SomeAction", target: NSObject(), sender: nil, event: nil)

        guard let span = SentrySDK.span as? SentryTracer else {
            XCTFail("Transaction not created")
            return
        }
        
        XCTAssertEqual(span.name, "[NSObject SomeAction]")
        XCTAssertEqual(span.context.operation, "ui.action")
    }
    
    func test_dont_Create_Transaction_Scope_Used() {
        let sut = fixture.getSut()
        sut.start()
        
        let span = SentrySDK.startTransaction(name: "SomeTransaction", operation: "OtherOperation", bindToScope: true) as? SentryTracer
        
        callExecuteAction(sut, action: "SomeAction", target: NSObject(), sender: nil, event: nil)
        
        let confirmSpan = SentrySDK.span
        
        XCTAssertTrue(span === confirmSpan)
        XCTAssertEqual(span?.children.count, 0)
    }
    
    func test_replace_UIEvent_transaction() {
        let sut = fixture.getSut()
        sut.start()
        callExecuteAction(sut, action: "SomeAction", target: NSObject(), sender: nil, event: nil)

        guard let firstSpan = SentrySDK.span as? SentryTracer else {
            XCTFail("First transaction not created")
            return
        }
        
        callExecuteAction(sut, action: "SomeAction", target: NSObject(), sender: nil, event: nil)
        guard let secondSpan = SentrySDK.span as? SentryTracer else {
            XCTFail("First transaction not created")
            return
        }
        
        XCTAssertFalse(firstSpan == secondSpan)
        XCTAssertTrue(firstSpan.isFinished)
    }
        
    func callExecuteAction(_ tracker : SentryUIEventTracker,  action: String, target : Any?, sender: Any?, event:  UIEvent?) {
        fixture.swizzleWrapper.execute(action: action, target: target, sender:sender, event: event);
    }
}
#endif
