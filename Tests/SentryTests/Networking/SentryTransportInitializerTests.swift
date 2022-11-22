@testable import Sentry
import XCTest

class SentryTransportInitializerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportInitializerTests")
    private static let dsn = TestConstants.dsn(username: "SentryTransportInitializerTests")
    
    private var fileManager: SentryFileManager!
    
    override func setUp() {
        super.setUp()
        let options = Options()
        options.dsn = SentryTransportInitializerTests.dsnAsString
        fileManager = SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }

    func testDefault() throws {
        let options = try Options(dsn: SentryTransportInitializerTests.dsnAsString)
        
        let result = TransportInitializer.initTransport(options, sentryFileManager: fileManager)
        
        XCTAssertTrue(result.isKind(of: SentryHttpTransport.self))
    }
}
