@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryTransportInitializerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportInitializerTests")
    
    private var fileManager: SentryFileManager!
    private var dateProvider: TestCurrentDateProvider!
    private var rateLimits: (any RateLimits)!

    override func setUp() {
        super.setUp()
        let options = Options()
        options.dsn = SentryTransportInitializerTests.dsnAsString
        fileManager = try! SentryFileManager(
            options: options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
        )
        dateProvider = TestCurrentDateProvider()
        rateLimits = SentryDependencyContainer.sharedInstance().rateLimits
    }

    func testDefault() throws {
        let options = try SentryOptionsInternal.initWithDict(["dsn": SentryTransportInitializerTests.dsnAsString])
    
        let result = TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: fileManager,
            rateLimits: rateLimits
        )
        XCTAssertEqual(result.count, 1)
        
        let firstTransport = result.first
        XCTAssertEqual(firstTransport?.isKind(of: SentryHttpTransport.self), true)
    }
}
