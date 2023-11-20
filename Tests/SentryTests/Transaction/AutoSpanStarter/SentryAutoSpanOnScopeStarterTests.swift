import Nimble
import SentryTestUtils
import XCTest

final class SentryAutoSpanOnScopeStarterTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testStartSpanUsesSpanOnScope() throws {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let transaction = hub.startTransaction(name: "MyTransaction", operation: "ui.load", bindToScope: true)
        
        SentryAutoSpanOnScopeStarter().startSpan { span in
            expect(SentrySDK.span) === span
            expect(transaction.spanId) == span?.spanId
        }
    }
    
    func testStartSpan_NoSpanOnScope() throws {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        SentryAutoSpanOnScopeStarter().startSpan { span in
            expect(span) == nil
        }
    }

}
