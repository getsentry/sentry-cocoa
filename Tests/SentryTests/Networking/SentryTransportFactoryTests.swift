import Sentry
import SentryTestUtils
import XCTest

class SentryTransportFactoryTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryTransportFactoryTests")

    func testIntegration_UrlSessionDelegate_PassedToRequestManager() {
        let urlSessionDelegateSpy = UrlSessionDelegateSpy()
        
        let expect = expectation(description: "UrlSession Delegate of Options called in RequestManager")
        urlSessionDelegateSpy.delegateCallback = {
            expect.fulfill()
        }
        
        let options = Options()
        options.dsn = SentryTransportFactoryTests.dsnAsString
        options.urlSessionDelegate = urlSessionDelegateSpy
        
        let fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let transport = TransportInitializer.initTransport(options, sentryFileManager: fileManager)
        let requestManager = Dynamic(transport).requestManager.asObject as! SentryQueueableRequestManager
        
        let imgUrl = URL(string: "https://github.com")!
        let request = URLRequest(url: imgUrl)
        
        requestManager.add(request) { _, _ in /* We don't care about the result */ }
        wait(for: [expect], timeout: 10)
    }
}
