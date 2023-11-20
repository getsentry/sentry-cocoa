import Nimble
import SentryTestUtils
import XCTest

final class SentryAutoSpanTransactionCarrierStarterTests: XCTestCase {
    
    private let timeout = 10.0
    private let dispatchQueue = TestSentryDispatchQueueWrapper()
    
    private func givenSut() -> SentryAutoSpanTransactionCarrierStarter {
        return SentryAutoSpanTransactionCarrierStarter(dispatchQueueWrapper: dispatchQueue, idleTimeout: timeout)
    }
    
    func testScopeHasSpan_StartSpanReturnsSpanOfScope() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let transaction = hub.startTransaction(name: "MyTransaction", operation: "ui.load", bindToScope: true)
        
        givenSut().startSpan { span in
            expect(span?.spanId).to(be(transaction.spanId))
        }
    }
    
    func testScopeHasNoSpan_StartSpanReturnsCarrierTransaction() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let sut = givenSut()
        
        sut.startSpan { span in
            
            expect(span?.parentSpanId) == nil
            expect(span?.operation) == "carrier"
            expect(span?.origin) == "auto.carrier"
            
            expect(span).to(beAnInstanceOf(SentryTracer.self))
            let tracer = span as? SentryTracer
            expect(tracer?.transactionContext.name) == "CarrierTransaction"
            expect(tracer?.transactionContext.nameSource) == .component
            
            let config = Dynamic(tracer).configuration.asObject as? SentryTracerConfiguration
            
            expect(config?.idleTimeout) == self.timeout
            expect(config?.waitForChildren) == true
            expect(config?.dispatchQueueWrapper) === self.dispatchQueue
            
            expect(SentrySDK.span) === span
        }
    }
    
    func testIsCarrierTransaction() {
        expect(SentryAutoSpanTransactionCarrierStarter.isCarrierTransaction("carrier")) == true
        
        expect(SentryAutoSpanTransactionCarrierStarter.isCarrierTransaction("carrie")) == false
    }

}
