import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryTransportFactoryTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportFactoryTests")
    
    func testIntegration_UrlSessionDelegate_PassedToRequestManager() throws {
        let urlSessionDelegateSpy = UrlSessionDelegateSpy()
        
        let expect = expectation(description: "UrlSession Delegate of Options called in RequestManager")
        urlSessionDelegateSpy.delegateCallback = {
            expect.fulfill()
        }
        
        let options = Options()
        options.dsn = SentryTransportFactoryTests.dsnAsString
        options.urlSessionDelegate = urlSessionDelegateSpy
        
        let fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
            sentryFileManager: fileManager,
            rateLimits: rateLimiting()
        )
        let httpTransport = transports.first
        let requestManager = try XCTUnwrap(Dynamic(httpTransport).requestManager.asObject as? SentryQueueableRequestManager)
        
        let imgUrl = URL(string: "https://github.com")!
        let request = URLRequest(url: imgUrl)
        
        requestManager.add(request) { _, _ in /* We don't care about the result */ }
        wait(for: [expect], timeout: 10)
    }
    
    func testShouldReturnTransports_WhenURLSessionPassed() throws {
        
        let urlSessionDelegateSpy = UrlSessionDelegateSpy()
        let expect = expectation(description: "UrlSession Delegate of Options called in RequestManager")

        let sessionConfiguration = URLSession(configuration: .ephemeral, delegate: urlSessionDelegateSpy, delegateQueue: nil)
        urlSessionDelegateSpy.delegateCallback = {
            expect.fulfill()
        }

        let options = Options()
        options.urlSession = sessionConfiguration
        
        let fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
            sentryFileManager: fileManager,
            rateLimits: rateLimiting()
        )
                
        let httpTransport = transports.first
        let requestManager = try XCTUnwrap(Dynamic(httpTransport).requestManager.asObject as? SentryQueueableRequestManager)
        
        let imgUrl = URL(string: "https://github.com")!
        let request = URLRequest(url: imgUrl)
        
        requestManager.add(request) { _, _ in /* We don't care about the result */ }
        wait(for: [expect], timeout: 10)

    }
    
    func testShouldReturnTwoTransports_WhenSpotlightEnabled() throws {
        let options = Options()
        options.enableSpotlight = true
        let transports = TransportInitializer.initTransports(
            options,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
            sentryFileManager: try SentryFileManager(options: options),
            rateLimits: rateLimiting()
        )
        
        XCTAssert(transports.contains {
            $0.isKind(of: SentrySpotlightTransport.self)
        })
        
        XCTAssert(transports.contains {
            $0.isKind(of: SentryHttpTransport.self)
        })
    }

    private func rateLimiting() -> RateLimits {
        let dateProvider = TestCurrentDateProvider()
        let retryAfterHeaderParser = RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: dateProvider)
        let rateLimitParser = RateLimitParser(currentDateProvider: dateProvider)
        
        return DefaultRateLimits(retryAfterHeaderParser: retryAfterHeaderParser, andRateLimitParser: rateLimitParser, currentDateProvider: dateProvider)
    }
    
}
