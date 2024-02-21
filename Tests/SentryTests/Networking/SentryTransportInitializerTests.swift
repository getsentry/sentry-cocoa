import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

class SentryTransportInitializerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportInitializerTests")
    
    private var fileManager: SentryFileManager!
    
    override func setUp() {
        super.setUp()
        let options = Options()
        options.dsn = SentryTransportInitializerTests.dsnAsString
        fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }

    func testDefault() throws {
        let options = try Options(dict: ["dsn": SentryTransportInitializerTests.dsnAsString])
    
        let result = TransportInitializer.initTransports(options, sentryFileManager: fileManager)
        expect(result.count) == 1
        
        let firstTransport = result.first
        expect(firstTransport?.isKind(of: SentryHttpTransport.self)) == true
    }
}
