import Nimble
import SentryTestUtils
import XCTest

final class CarrierTransactionIntegrationTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    private let timeout = 10.0
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

    func testTimetTimesOut() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let spanCreator = AutoSpanCreator(spanStarter: self.givenSpanStarter())
        
        spanCreator.createAutoSpan()
        let span = SentrySDK.span
        
        dispatchQueue.invokeLastDispatchAfter()
        
        expect(hub.capturedTransactionsWithScope.count) == 1
        expect(span?.isFinished) == true
    }
}

class AutoSpanCreator {
    
    private let spanStarter: SentryAutoSpanStarter
    
    init(spanStarter: SentryAutoSpanStarter) {
        self.spanStarter = spanStarter
    }
    
    func createAutoSpan() {
        spanStarter.startSpan { span in
            span?.startChild(operation: "file.read")
        }
    }
    
}
