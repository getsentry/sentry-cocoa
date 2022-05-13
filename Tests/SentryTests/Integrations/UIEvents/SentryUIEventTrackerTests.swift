import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIEventTrackerTests: XCTestCase {

    private class Fixture {
        let swizzleWrapper = TestSentrySwizzleWrapper()
        let target = FirstViewController()
        let hub = SentryHub(client: TestClient(options: Options()), andScope: nil)
        
        func getSut() -> SentryUIEventTracker {
            return SentryUIEventTracker(swizzleWrapper: swizzleWrapper, dispatchQueueWrapper: SentryDispatchQueueWrapper())
        }
    }

    private var fixture: Fixture!
    private var sut: SentryUIEventTracker!
    
    let operation = "ui.action"
    let operationClick = "ui.action.click"
    let action = "SomeAction"
    let accessibilityIdentifier = "accessibilityIdentifier"
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        sut = fixture.getSut()
        sut.start()
        
        SentrySDK.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.swizzleWrapper.removeAllCallbacks()
        clearTestState()
    }
    
    func test_Create_Transaction() {
        callExecuteAction(action: action, target: NSObject(), sender: nil, event: nil)
        
        assertTransaction(name: "NSObject.\(action)", operation: operation)
    }
    
    func test_UIViewWithAccessibilityIdentifier_UseAccessibilityIdentifier() {
        let view = UIView()
        view.accessibilityIdentifier = accessibilityIdentifier
        
        callExecuteAction(action: action, target: fixture.target, sender: view, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(accessibilityIdentifier)", operation: operationClick)
    }
    
    func test_UIViewWithoutAccessibilityIdentifier_UseAction() {
        callExecuteAction(action: action, target: fixture.target, sender: UIView(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(action)", operation: operationClick)
    }
    
    func test_UIEventWithPresses_IsClickOperation() {
        callExecuteAction(action: "captureMessage", target: fixture.target, sender: nil, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.captureMessage", operation: operationClick)
    }
    
    func test_UIEventWithTouches_IsClickOperation() {
        let event = TestUIEvent()
        event.internalType = .touches
        callExecuteAction(action: "captureMessage", target: fixture.target, sender: nil, event: event)
        
        assertTransaction(name: "SentryTests.FirstViewController.captureMessage", operation: operationClick)
    }
    
    func test_Create_Transaction_noTarget() {
        callExecuteAction(action: action, target: nil, sender: nil, event: nil)
        
        assertTransaction(name: action, operation: operation)
    }
    
    func test_OnGoingUILoadTransaction_StartNewUIEventTransaction_NotBoundToScope() {
        let uiLoadTransaction = SentrySDK.startTransaction(name: "test", operation: "ui.load", bindToScope: true)
        
        callExecuteAction(action: action, target: fixture.target, sender: nil, event: TestUIEvent())
        
        XCTAssertTrue(uiLoadTransaction === SentrySDK.span)
        
        let transactions = Dynamic(sut).transactions.asArray
        XCTAssertEqual(1, transactions?.count)
    }
    
    func test_ManualTransactionOnScope_StartNewUIEventTransaction_NotBoundToScope() {
        let manualTransaction = SentrySDK.startTransaction(name: "test", operation: "my.operation", bindToScope: true)
        
        callExecuteAction(action: action, target: fixture.target, sender: nil, event: TestUIEvent())
        
        XCTAssertTrue(manualTransaction === SentrySDK.span)
        
        let transactions = Dynamic(sut).transactions.asArray
        XCTAssertEqual(1, transactions?.count)
    }
    
    func test_SameUIElementWithSameEvent_ResetsTimeout() {
        callExecuteAction(action: action, target: fixture.target, sender: UIView(), event: TestUIEvent())

        callExecuteAction(action: action, target: fixture.target, sender: UIView(), event: TestUIEvent())
    
    }
    
    func test_SameUIElementWithDifferentEvent_FinishesTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: UIView(), event: TestUIEvent())
        
        let event = TestUIEvent()
        event.internalType = .motion
        
        callExecuteAction(action: action, target: fixture.target, sender: UIView(), event: event)
        
    }
    
    func test_DifferentUIElement_FinishesTransaction() {
        let view1 = UIView()
        callExecuteAction(action: action, target: fixture.target, sender: view1, event: TestUIEvent())
        
        let view2 = UIView()
        callExecuteAction(action: action, target: fixture.target, sender: view2, event: TestUIEvent())
    }
    
    func test_Stop() {
        XCTAssertEqual(fixture.swizzleWrapper.callbacks.count, 1)
        sut.stop()
        XCTAssertTrue(fixture.swizzleWrapper.callbacks.isEmpty)
    }
        
    func callExecuteAction(action: String, target: Any?, sender: Any?, event: UIEvent?) {
        fixture.swizzleWrapper.execute(action: action, target: target, sender: sender, event: event)
    }
    
    private func testClickOperationFor(_ event: TestUIEvent) {
        callExecuteAction(action: "captureMessage", target: fixture.target, sender: nil, event: event)
        
        assertTransaction(name: "SentryTests.FirstViewController.captureMessage", operation: operationClick)
    }
    
    private func assertTransaction(name: String, operation: String) {
        guard let span = SentrySDK.span as? SentryTracer else {
            XCTFail("Transaction not created")
            return
        }
        
        XCTAssertEqual(name, span.name)
        XCTAssertEqual(operation, span.context.operation)
    }
    
    private class TestUIEvent: UIEvent {
        
        var internalType: UIEvent.EventType = .presses
        override var type: UIEvent.EventType {
            return internalType
        }
    }
}
#endif
