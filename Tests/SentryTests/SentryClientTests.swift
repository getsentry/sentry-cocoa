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
            let options = try Options(dict: [
                "attachStacktrace": true,
                "dsn": TestConstants.dsnAsString
            ])
    
            client = Client(options: options, andTransport: transport, andFileManager: try SentryFileManager(dsn: TestConstants.dsn))
        } catch {
            XCTFail("Options could not be created")
        }
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }

    func testCaptureMessage() {
        let message = "message"
        client.capture(message: message, scope: nil)
        
        let actual = transport.lastSentEvent
        XCTAssertEqual(SentryLevel.info, actual?.level)
        XCTAssertEqual(message, actual?.message)
    }
}
