import Nimble
import SentryTestUtils
import XCTest

final class CarrierTransactionIntegrationTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    private let timeout = 3.0
    private let dispatchQueue = TestSentryDispatchQueueWrapper()
    
    private func givenSpanStarter() -> SentryAutoSpanTransactionCarrierStarter {
        return SentryAutoSpanTransactionCarrierStarter(dispatchQueueWrapper: dispatchQueue, idleTimeout: timeout)
    }

    func testNoTransactionBoundToScope() {
        let spanCreator = AutoSpanCreator(spanStarter: self.givenSpanStarter())
        spanCreator.createAutoSpan()
        
        let span = SentrySDK.span
        expect(span?.operation) == "carrier"
        expect(span?.origin) == "auto.carrier"
        expect(span).to(beAnInstanceOf(SentryTracer.self))
    }

    func testTimerTimesOut_WithFinishedSpans() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let spanCreator = AutoSpanCreator(spanStarter: self.givenSpanStarter())
        spanCreator.createAutoSpan()
        
        let span = try! XCTUnwrap(SentrySDK.span as? SentryTracer)
        expect(span.transactionContext.name) == "CarrierTransaction"
        expect(span.isFinished) == false
        
        timerTimesOut()
        
        expect(hub.capturedTransactionsWithScope.count) == 1
        expect(span.isFinished) == true
        expect(span.status) == .undefined
        expect(SentrySDK.span) == nil
    }
    
    private func timerTimesOut() {
        dispatchQueue.invokeLastDispatchAfter()
    }
}

class AutoSpanCreator {
    
    private let spanStarter: SentryAutoSpanStarter
    
    init(spanStarter: SentryAutoSpanStarter) {
        self.spanStarter = spanStarter
    }
    
    func createAutoSpan() {
        spanStarter.startSpan { span in
            let fileSpan = span?.startChild(operation: "file.read")
            fileSpan?.finish()
        }
    }
    
    func createAutoSpanWithUnfinishedSpans() {
        spanStarter.startSpan { span in
            _ = span?.startChild(operation: "file.read")
        }
    }
    
}
