import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIEventTrackerTests: XCTestCase {

    private class Fixture {
        let swizzleWrapper = TestSentrySwizzleWrapper()
        let target = FirstViewController()
        let hub = SentryHub(client: TestClient(options: Options()), andScope: nil)
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let button = UIButton()
        
        func getSut() -> SentryUIEventTracker {
            return SentryUIEventTracker(swizzleWrapper: swizzleWrapper, dispatchQueueWrapper: dispatchQueue)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryUIEventTracker!
    
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
    
    func test_NSObject_NoTransaction() {
        callExecuteAction(action: action, target: NSObject(), sender: nil, event: nil)
        
        assertNoTransaction()
    }
    
    func test_NoTarget_NoTransaction() {
        callExecuteAction(action: action, target: nil, sender: UIView(), event: nil)
        
        assertNoTransaction()
    }
    
    func test_UIView_NoTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: UIView(), event: nil)
        
        assertNoTransaction()
    }
    
    func test_UIViewWithAccessibilityIdentifier_UseAccessibilityIdentifier() {
        let button = fixture.button
        button.accessibilityIdentifier = accessibilityIdentifier
        
        callExecuteAction(action: action, target: fixture.target, sender: button, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(accessibilityIdentifier)", operation: operationClick)
    }
    
    func test_UIButtonWithoutAccessibilityIdentifier_UseAction() {
        callExecuteAction(action: action, target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(action)", operation: operationClick)
    }
    
    func test_UISegmentedControl_CreatesTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: UISegmentedControl(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(action)", operation: operationClick)
    }
    
    func test_UIPageControl_CreatesTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: UISegmentedControl(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(action)", operation: operationClick)
    }
    
    func test_UIEventWithMotion_IsClickOperation() {
        let event = TestUIEvent()
        event.internalType = .motion
        callExecuteAction(action: "captureMessage", target: fixture.target, sender: fixture.button, event: event)
        
        assertTransaction(name: "SentryTests.FirstViewController.captureMessage", operation: operationClick)
    }
    
    func test_OnGoingUILoadTransaction_StartNewUIEventTransaction_NotBoundToScope() {
        let uiLoadTransaction = SentrySDK.startTransaction(name: "test", operation: "ui.load", bindToScope: true)
        
        callExecuteAction(action: action, target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        XCTAssertTrue(uiLoadTransaction === SentrySDK.span)
    }
    
    func test_ManualTransactionOnScope_StartNewUIEventTransaction_NotBoundToScope() {
        let manualTransaction = SentrySDK.startTransaction(name: "test", operation: "my.operation", bindToScope: true)
        
        callExecuteAction(action: action, target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        XCTAssertTrue(manualTransaction === SentrySDK.span)
    }
    
    func test_SameUIElementWithSameEvent_ResetsTimeout() {
        let view = fixture.button
        
        callExecuteAction(action: action, target: fixture.target, sender: view, event: TestUIEvent())
        let firstTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)

        callExecuteAction(action: action, target: fixture.target, sender: view, event: TestUIEvent())
        let secondTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        assertResetsTimeout(firstTransaction, secondTransaction)
    }
    
    func test_SameUIElementWithSameEvent_TransactionFinished_NewTransaction() {
        let view = fixture.button
        callExecuteAction(action: action, target: fixture.target, sender: view, event: TestUIEvent())
        
        let firstTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        callExecuteAction(action: action, target: fixture.target, sender: view, event: TestUIEvent())
        
        let secondTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        XCTAssertFalse(firstTransaction === secondTransaction)
    }
    
    func test_DifferentUIElement_FinishesTransaction() {
        let view1 = fixture.button
        callExecuteAction(action: action, target: fixture.target, sender: view1, event: TestUIEvent())
        
        let firstTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        let view2 = UIButton()
        callExecuteAction(action: action, target: fixture.target, sender: view2, event: TestUIEvent())
        
        assertFinishesTransaction(firstTransaction, operationClick)
    }
    
    func test_Stop() {
        XCTAssertEqual(fixture.swizzleWrapper.callbacks.count, 1)
        sut.stop()
        XCTAssertTrue(fixture.swizzleWrapper.callbacks.isEmpty)
    }
    
    func test_IsUIEventOperation_UIAction() {
        XCTAssertTrue(SentryUIEventTracker.isUIEventOperation("ui.action"))
    }
    
    func test_IsUIEventOperation_UIActionClick() {
        XCTAssertTrue(SentryUIEventTracker.isUIEventOperation("ui.action.click"))
    }
    
    func test_IsUIEventOperation_Unknown() {
        XCTAssertFalse(SentryUIEventTracker.isUIEventOperation("unkown"))
    }
        
    func callExecuteAction(action: String, target: Any?, sender: Any?, event: UIEvent?) {
        fixture.swizzleWrapper.execute(action: action, target: target, sender: sender, event: event)
    }
    
    private func assertTransaction(name: String, operation: String) {
        let span = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        XCTAssertTrue(span === Dynamic(sut).activeTransaction.asObject)
        
        XCTAssertEqual(name, span.name)
        XCTAssertEqual(operation, span.context.operation)
    }
    
    private func assertNoTransaction() {
        XCTAssertNil(SentrySDK.span as? SentryTracer)
    }
    
    private func assertResetsTimeout(_ firstTransaction: SentryTracer, _ secondTransaction: SentryTracer) {
        XCTAssertTrue(firstTransaction === secondTransaction)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations.count)
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
    }
    
    private func assertFinishesTransaction(_ transaction: SentryTracer, _ operation: String) {
        XCTAssertTrue(transaction.isFinished)
        XCTAssertEqual(.ok, transaction.context.status)
        assertTransaction(name: "SentryTests.FirstViewController.\(action)", operation: operation)
    }
    
    private class TestUIEvent: UIEvent {
        
        var internalType: UIEvent.EventType = .touches
        override var type: UIEvent.EventType {
            return internalType
        }
    }
}
#endif
