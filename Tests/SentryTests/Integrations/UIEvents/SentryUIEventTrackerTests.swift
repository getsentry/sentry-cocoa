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
            return SentryUIEventTracker(swizzleWrapper: swizzleWrapper, dispatchQueueWrapper: dispatchQueue, idleTimeout: 3.0)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryUIEventTracker!
    
    let operation = "ui.action"
    let operationClick = "ui.action.click"
    let action = "SomeAction:"
    let expectedAction = "SomeAction"
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
    
    func test_NSSender_NoTransaction() {
        callExecuteAction(action: action, target: NSObject(), sender: nil, event: nil)
        
        assertNoTransaction()
    }
    
    func test_NoTarget_NoTransaction() {
        callExecuteAction(action: action, target: nil, sender: UIView(), event: nil)
        
        assertNoTransaction()
    }
    
    // swiftlint:disable type_name
    // We want to emulate a class name generated by SwiftUI
    func test_TargetContainsSwiftUI_NoTransaction() {
        
        class _Bla_SwiftUIForFun_UglyLongName_Coordinator { }
        
        callExecuteAction(action: action, target: _Bla_SwiftUIForFun_UglyLongName_Coordinator(), sender: UIView(), event: TestUIEvent())
        
        assertNoTransaction()
    }
    // swiftlint:enable type_name
    
    func test_NSObject_Transaction() {
        callExecuteAction(action: "method:", target: fixture.target, sender: NSObject(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.method", operation: operation)
    }
    
    func test_UIView_Transaction() {
        callExecuteAction(action: "method:", target: fixture.target, sender: UIView(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.method", operation: operation)
    }
    
    func testAction_WithNoArgument() {
        callExecuteAction(action: "method:", target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.method", operation: operationClick)
    }
    
    func testAction_WithOneArgument() {
        callExecuteAction(action: "method:firstArgument:", target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.method(firstArgument:)", operation: operationClick)
    }
    
    func testAction_WithThreeArguments() {
        callExecuteAction(action: "method:first:second:third:", target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.method(first:second:third:)", operation: operationClick)
    }
    
    func test_UIViewWithAccessibilityIdentifier_UseAccessibilityIdentifier() {
        let button = fixture.button
        button.accessibilityIdentifier = accessibilityIdentifier
        
        callExecuteAction(action: action, target: fixture.target, sender: button, event: TestUIEvent())
        
        let span = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        XCTAssertTrue(span.tags.contains {
            $0.key == "accessibilityIdentifier" && $0.value == accessibilityIdentifier
        })
    }
    
    func test_SubclassOfUIButton_CreatesTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: TestUIButton(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(expectedAction)", operation: operationClick)
    }
    
    func test_UISegmentedControl_CreatesTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: UISegmentedControl(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(expectedAction)", operation: operationClick)
    }
    
    func test_UIPageControl_CreatesTransaction() {
        callExecuteAction(action: action, target: fixture.target, sender: UISegmentedControl(), event: TestUIEvent())
        
        assertTransaction(name: "SentryTests.FirstViewController.\(expectedAction)", operation: operationClick)
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
    
    func test_DifferentUIElement_SameAction_ResetsTimeout() {
        let view1 = fixture.button
        callExecuteAction(action: action, target: fixture.target, sender: view1, event: TestUIEvent())
        
        let firstTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        let view2 = UIView()
        callExecuteAction(action: action, target: fixture.target, sender: view2, event: TestUIEvent())
        let secondTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        assertResetsTimeout(firstTransaction, secondTransaction)
    }
    
    func test_DifferentUIElement_DifferentAction_FinishesTransaction() {
        let view1 = fixture.button
        callExecuteAction(action: "otherAction", target: fixture.target, sender: view1, event: TestUIEvent())
        
        let firstTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        let view2 = UIButton()
        callExecuteAction(action: action, target: fixture.target, sender: view2, event: TestUIEvent())
        
        assertFinishesTransaction(firstTransaction, operationClick)
    }
    
    func testFinishedTransaction_DoesntFinishImmidiately_KeepsTransactionInMemory() {
        
        // We want firstTransaction to be deallocated by ARC
        func startChild() -> Span {
            let firstTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
            return firstTransaction.startChild(operation: "some")
        }
        
        callExecuteAction(action: action, target: fixture.target, sender: fixture.button, event: TestUIEvent())
        
        let child = startChild()

        callExecuteAction(action: "otherAction", target: fixture.target, sender: UIView(), event: TestUIEvent())
        
        XCTAssertEqual(2, getInternalTransactions().count)
        
        let secondTransaction = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        XCTAssertTrue(secondTransaction === getInternalTransactions().last)
        
        child.finish()
        
        XCTAssertEqual(1, getInternalTransactions().count)
        XCTAssertTrue(secondTransaction === getInternalTransactions().last)
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
    
    private func getInternalTransactions() -> [SentryTracer] {
        return try! XCTUnwrap(Dynamic(sut).activeTransactions.asArray as? [SentryTracer])
    }
    
    private func assertTransaction(name: String, operation: String, nameSource: SentryTransactionNameSource = .component) {
        let span = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        let transactions = try! XCTUnwrap(Dynamic(sut).activeTransactions.asArray as? [SentryTracer])
        XCTAssertEqual(1, transactions.count)
        XCTAssertTrue(span === transactions.first)
        
        XCTAssertEqual(name, span.transactionContext.name)
        XCTAssertEqual(nameSource, span.transactionContext.nameSource)
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
        assertTransaction(name: "SentryTests.FirstViewController.\(expectedAction)", operation: operation)
        
        let transactions = getInternalTransactions()
        XCTAssertEqual(1, transactions.count)
    }
    
    private class TestUIEvent: UIEvent {}
    
    private class TestUIButton: UIButton {}
}
#endif
