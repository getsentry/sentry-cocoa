import XCTest

class SentryNetworkTrackIntegrationTests: XCTestCase {
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    private class Fixture {
        let options: Options
       
        init() {
            options = Options()
            options.dsn = SentryNetworkTrackIntegrationTests.dsnAsString
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testProtocolGetRegisteredAndUnregistered() {
        NSURLProtocolSwizzle.swizzleURLProtocol()
        
        var registerCallbackCalled = false
        NSURLProtocolSwizzle.shared.registerCallback = { protocolClass in
            registerCallbackCalled = true
            XCTAssertTrue(protocolClass === SentryHttpInterceptor.self)
        }
        
        var unregisterCallbackCalled = false
        NSURLProtocolSwizzle.shared.unregisterCallback = { protocolClass in
            unregisterCallbackCalled = true
            XCTAssertTrue(protocolClass === SentryHttpInterceptor.self)
        }
        let integration = SentryNetworkTrackingIntegration()
        integration.install(with: fixture.options)
        XCTAssertTrue(registerCallbackCalled)
        
        integration.uninstall()
        XCTAssertTrue(unregisterCallbackCalled)
        
        NSURLProtocolSwizzle.shared.registerCallback = nil
        NSURLProtocolSwizzle.shared.unregisterCallback = nil
    }
    
    func testProtocolDontGetRegistered() {
        NSURLProtocolSwizzle.swizzleURLProtocol()
        NSURLProtocolSwizzle.shared.registerCallback = { _ in
            XCTAssert(false)
        }
        let integration = SentryNetworkTrackingIntegration()
        fixture.options.enableAutoPerformanceTracking = false
        integration.install(with: fixture.options)
        integration.uninstall()
    }
}
