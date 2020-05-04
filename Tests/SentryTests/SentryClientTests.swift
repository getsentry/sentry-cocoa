@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

class SentryClientTest: XCTestCase {
    
    private var client: Client!
    private var transport: TestTransport!
    
    
    override func setUp() {
        super.setUp()
        
        transport = TestTransport()
        
        do {
            let options = try Options(dict: ["dsn": TestConstants.dsnAsString,
                                             "transport": transport])
            client = Client(options: options)
        } catch {
            XCTFail("Options could not be created")
        }
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }

    // Skippes until we expose a way to replace the transport
    func skipped_testCaptureMessage() {
        let message = "message"
        client.capture(message: message, scope: nil)
        
        let actual = transport.lastSentEvent
        XCTAssertEqual(SentryLevel.info, actual?.level)
        XCTAssertEqual(message, actual?.message)
    }
}
