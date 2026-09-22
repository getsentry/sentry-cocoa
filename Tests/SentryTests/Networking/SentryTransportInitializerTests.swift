@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryTransportInitializerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportInitializerTests")
    
    private var fileManager: SentryFileManager!
    private var dateProvider: TestCurrentDateProvider!
    private var rateLimits: (any RateLimits)!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let options = Options()
        options.dsn = SentryTransportInitializerTests.dsnAsString
        fileManager = try XCTUnwrap(SentryFileManager(
            options: options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
        ))
        dateProvider = TestCurrentDateProvider()
        rateLimits = SentryDependencyContainer.sharedInstance().rateLimits
    }

    func testDefault() throws {
        let options = Options()
        options.dsn = SentryTransportInitializerTests.dsnAsString
    
        let result = TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: fileManager,
            rateLimits: rateLimits,
            reachability: TestSentryReachability()
        )
        XCTAssertEqual(result.count, 1)
        
        let firstTransport = result.first
        #if SWIFT_PACKAGE
        XCTAssertTrue(SentryTestIsHttpTransport(try XCTUnwrap(firstTransport)))
        #else
        XCTAssertEqual(firstTransport?.isKind(of: SentryHttpTransport.self), true)
        #endif
    }
}
