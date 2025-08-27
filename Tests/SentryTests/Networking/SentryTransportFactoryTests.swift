import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryTransportFactoryTests: XCTestCase {
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportFactoryTests")
    
    func testIntegration_UrlSessionDelegate_PassedToRequestManager() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let urlSessionDelegateSpy = UrlSessionDelegateSpy()
        
        let expect = expectation(description: "UrlSession Delegate of Options called in RequestManager")
        urlSessionDelegateSpy.delegateCallback = {
            expect.fulfill()
        }
        
        let options = Options()
        options.dsn = SentryTransportFactoryTests.dsnAsString
        options.urlSessionDelegate = urlSessionDelegateSpy
        
        let fileManager = try! SentryFileManager(
            options: options,
            dateProvider: dateProvider,
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
        )

        // -- Act --
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: fileManager,
            rateLimits: rateLimiting()
        )
        let httpTransport = transports.first
        let requestManager = try XCTUnwrap(Dynamic(httpTransport).requestManager.asObject as? SentryQueueableRequestManager)
        
        let imgUrl = URL(string: "https://github.com")!
        let request = URLRequest(url: imgUrl)
        
        requestManager.add(request) { _, _ in /* We don't care about the result */ }

        // -- Assert --
        wait(for: [expect], timeout: 10)
    }
    
    func testShouldReturnTransports_WhenURLSessionPassed() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let urlSessionDelegateSpy = UrlSessionDelegateSpy()
        let expect = expectation(description: "UrlSession Delegate of Options called in RequestManager")

        let sessionConfiguration = URLSession(configuration: .ephemeral, delegate: urlSessionDelegateSpy, delegateQueue: nil)
        urlSessionDelegateSpy.delegateCallback = {
            expect.fulfill()
        }

        let options = Options()
        options.dsn = SentryTransportFactoryTests.dsnAsString
        options.urlSession = sessionConfiguration
        
        let fileManager = try! SentryFileManager(
            options: options,
            dateProvider: dateProvider,
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
        )

        // -- Act --
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: fileManager,
            rateLimits: rateLimiting()
        )
                
        let httpTransport = transports.first
        let requestManager = try XCTUnwrap(Dynamic(httpTransport).requestManager.asObject as? SentryQueueableRequestManager)
        
        let imgUrl = URL(string: "https://github.com")!
        let request = URLRequest(url: imgUrl)
        
        requestManager.add(request) { _, _ in /* We don't care about the result */ }

        // -- Assert --
        wait(for: [expect], timeout: 10)

    }
    
    func testShouldReturnTwoTransports_WhenSpotlightEnabled() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()

        let options = Options()
        options.dsn = SentryTransportFactoryTests.dsnAsString
        options.enableSpotlight = true

        // -- Act --
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            ),
            rateLimits: rateLimiting()
        )

        // -- Assert --
        XCTAssertEqual(transports.count, 2)
        XCTAssert(transports.contains {
            $0.isKind(of: SentrySpotlightTransport.self)
        })
        XCTAssert(transports.contains {
            $0.isKind(of: SentryHttpTransport.self)
        })
    }

    func testInitTransports_whenOptionsParsedDsnNilAndSpotlightDisabled_shouldReturnEmptyTransports() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()

        let options = Options()
        options.dsn = nil
        options.enableSpotlight = false

        // -- Act --
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            ),
            rateLimits: rateLimiting()
        )

        // -- Assert --
        XCTAssertEqual(transports.count, 0)
    }

    func testInitTransports_whenOptionsParsedDsnNilAndSpotlightEnabled_shouldReturnSpotlightTransport() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()

        let options = Options()
        options.dsn = nil
        options.enableSpotlight = true

        // -- Act --
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
            sentryFileManager: try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
            ),
            rateLimits: rateLimiting()
        )

        // -- Assert --
        XCTAssertEqual(transports.count, 1)
        XCTAssert(transports.contains {
            $0.isKind(of: SentrySpotlightTransport.self)
        })
    }

    // MARK: - Helpers

    private func rateLimiting() -> RateLimits {
        let dateProvider = TestCurrentDateProvider()
        let retryAfterHeaderParser = RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: dateProvider)
        let rateLimitParser = RateLimitParser(currentDateProvider: dateProvider)
        
        return DefaultRateLimits(retryAfterHeaderParser: retryAfterHeaderParser, andRateLimitParser: rateLimitParser, currentDateProvider: dateProvider)
    }
}
