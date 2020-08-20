import XCTest

class SentryHubTests: XCTestCase {
    
    private class Fixture {
        let options: Options
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User wants to crash", userInfo: nil)
        var client: TestClient!
        let crumb = Breadcrumb(level: .error, category: "default")
        let scope = Scope()
        let message = "some message"
        let event: Event
        
        init() {
            options = Options()
            options.dsn = "https://username@sentry.io/1"
            
            scope.add(crumb)
            
            event = Event()
            event.message = message
        }
        
        func getSut(withMaxBreadcrumbs maxBreadcrumbs: UInt = 100) -> SentryHub {
            options.maxBreadcrumbs = maxBreadcrumbs
            return getSut(options)
        }
        
        func getSut(_ options: Options) -> SentryHub {
            client = TestClient(options: options)
            let hub = SentryHub(client: client, andScope: nil)
            hub.bindClient(client)
            return hub
        }
    }

    private let fixture = Fixture()
    
    func testBeforeBreadcrumbWithoutCallbackStoresBreadcrumb() {
        let hub = fixture.getSut()
        // TODO: Add a better API
        let crumb = Breadcrumb(
            level: .error,
            category: "default")
        hub.add(crumb)
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"]
        XCTAssertNotNil(scopeBreadcrumbs)
    }
    
    func testBeforeBreadcrumbWithCallbackReturningNullDropsBreadcrumb() {
        let options = fixture.options
        options.beforeBreadcrumb = { crumb in return nil }
        
        let hub = fixture.getSut(options)
        
        let crumb = Breadcrumb(
            level: .error,
            category: "default")
        hub.add(crumb)
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"]
        XCTAssertNil(scopeBreadcrumbs)
    }
    
    func testBreadcrumbLimitThroughOptionsUsingHubAddBreadcrumb() {
        let hub = fixture.getSut(withMaxBreadcrumbs: 10)

        for _ in 0...10 {
            let crumb = Breadcrumb(
                level: .error,
                category: "default")
            hub.add(crumb)
        }

        assert(withScopeBreadcrumbsCount: 10, with: hub)
    }
    
    func testBreadcrumbLimitThroughOptionsUsingConfigureScope() {
        let hub = fixture.getSut(withMaxBreadcrumbs: 10)

        for _ in 0...10 {
            addBreadcrumbThroughConfigureScope(hub)
        }

        assert(withScopeBreadcrumbsCount: 10, with: hub)
    }
    
    func testBreadcrumbCapLimit() {
        let hub = fixture.getSut()

        for _ in 0...100 {
            addBreadcrumbThroughConfigureScope(hub)
        }

        assert(withScopeBreadcrumbsCount: 100, with: hub)
    }
    
    func testBreadcrumbOverDefaultLimit() {
        let hub = fixture.getSut(withMaxBreadcrumbs: 200)

        for _ in 0...200 {
            addBreadcrumbThroughConfigureScope(hub)
        }

        assert(withScopeBreadcrumbsCount: 200, with: hub)
    }
    
    func testAddUserToTheScope() {
        let client = Client(options: fixture.options)
        let hub = SentryHub(client: client, andScope: Scope())

        let user = User()
        user.userId = "123"
        hub.setUser(user)
        
        let scope = hub.getScope()

        let scopeSerialized = scope.serialize()
        let scopeUser = scopeSerialized["user"] as? [String: Any?]
        let scopeUserId = scopeUser?["id"] as? String

        XCTAssertEqual(scopeUserId, "123")
    }
    
    func testCaptureEventWithScope() {
        fixture.getSut().capture(event: fixture.event, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureEventArguments.count)
        if let firstCapturedEvent = fixture.client.captureEventArguments.first {
            XCTAssertEqual(fixture.event.eventId, firstCapturedEvent.first.eventId)
            XCTAssertEqual(fixture.scope, firstCapturedEvent.second)
        }
    }
    
    func testCaptureEventWithoutScope() {
        fixture.getSut().capture(event: fixture.event, scope: nil)
        
        XCTAssertEqual(1, fixture.client.captureEventArguments.count)
        if let firstCapturedEvent = fixture.client.captureEventArguments.first {
            XCTAssertEqual(fixture.event.eventId, firstCapturedEvent.first.eventId)
            XCTAssertNil(firstCapturedEvent.second)
        }
    }
    
    func testCaptureMessageWithScope() {
        fixture.getSut().capture(message: fixture.message, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureMessageArguments.count)
        if let firstCapturedMessage = fixture.client.captureMessageArguments.first {
            XCTAssertEqual(fixture.message, firstCapturedMessage.first)
            XCTAssertEqual(fixture.scope, firstCapturedMessage.second)
        }
    }
    
    func testCaptureMessageWithoutScope() {
        fixture.getSut().capture(message: fixture.message, scope: nil)
        
        XCTAssertEqual(1, fixture.client.captureMessageArguments.count)
        if let firstCapturedMessage = fixture.client.captureMessageArguments.first {
            XCTAssertEqual(fixture.message, firstCapturedMessage.first)
            XCTAssertNil(firstCapturedMessage.second)
        }
    }
    
    func testCatpureErrorWithScope() {
        XCTAssertNotNil(fixture.getSut().capture(error: fixture.error, scope: fixture.scope))
        
        XCTAssertEqual(1, fixture.client.captureErrorArguments.count)
        if let firstCaptureError = fixture.client.captureErrorArguments.first {
            let actualError = firstCaptureError.first as NSError
            let actualScope = firstCaptureError.second
            
            XCTAssertEqual(fixture.error, actualError)
            XCTAssertEqual(fixture.scope, actualScope)
        }
    }
    
    func testCatpureErrorWithoutScope() {
        XCTAssertNotNil(fixture.getSut().capture(error: fixture.error, scope: nil))
        
        XCTAssertEqual(1, fixture.client.captureErrorArguments.count)
        if let firstCaptureError = fixture.client.captureErrorArguments.first {
            XCTAssertEqual(fixture.error, firstCaptureError.first as NSError)
            let actualScope = firstCaptureError.second
            XCTAssertNil(actualScope)
        }
    }
    
    func testCatpureExceptionWithScope() {
        XCTAssertNotNil(fixture.getSut().capture(exception: fixture.exception, scope: fixture.scope))
        
        XCTAssertEqual(1, fixture.client.captureExceptionArguments.count)
        if let firstCaptureError = fixture.client.captureExceptionArguments.first {
            XCTAssertEqual(fixture.exception, firstCaptureError.first)
            XCTAssertEqual(fixture.scope, firstCaptureError.second)
        }
    }
    
    func testCatpureExceptionWithoutScope() {
        XCTAssertNotNil(fixture.getSut().capture(exception: fixture.exception, scope: nil))
        
        XCTAssertEqual(1, fixture.client.captureExceptionArguments.count)
        if let firstCaptureError = fixture.client.captureExceptionArguments.first {
            XCTAssertEqual(fixture.exception, firstCaptureError.first)
            let actualScope = firstCaptureError.second
            XCTAssertNil(actualScope)
        }
    }
    
    func testCaptureClientIsNil_ReturnsEmptySentryId() {
        let sut = fixture.getSut()
        sut.bindClient(nil)
        
        XCTAssertEqual(SentryId.empty, sut.capture(error: fixture.error, scope: nil))
        XCTAssertEqual(0, fixture.client.captureErrorArguments.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(message: fixture.message, scope: fixture.scope))
        XCTAssertEqual(0, fixture.client.captureMessageArguments.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(event: fixture.event, scope: nil))
        XCTAssertEqual(0, fixture.client.captureEventArguments.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(exception: fixture.exception, scope: nil))
        XCTAssertEqual(0, fixture.client.captureExceptionArguments.count)
    }
    
    private func addBreadcrumbThroughConfigureScope(_ hub: SentryHub) {
        hub.configureScope({ scope in
            scope.add(self.fixture.crumb)
        })
    }
    
    private func assert(withScopeBreadcrumbsCount count: Int, with hub: SentryHub) {
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"] as? [AnyHashable]
        XCTAssertNotNil(scopeBreadcrumbs)
        XCTAssertEqual(scopeBreadcrumbs?.count, count)
    }
}
