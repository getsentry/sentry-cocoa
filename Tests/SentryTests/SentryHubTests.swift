import XCTest

class SentryHubTests: XCTestCase {
    
    private class Fixture {
        let options: Options
        
        init() {
            options = Options()
            options.dsn = "https://username@sentry.io/1"
        }
        
        func getSut(withMaxBreadcrumbs maxBreadcrumbs: UInt = 100) -> SentryHub {
            options.maxBreadcrumbs = maxBreadcrumbs
            return getSut(options)
        }
        
        func getSut(_ options: Options) -> SentryHub {
            let client = Client(options: options)
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
    
    private func addBreadcrumbThroughConfigureScope(_ hub: SentryHub) {
        hub.configureScope({ scope in
            let crumb = Breadcrumb(
                level: .error,
                category: "default")
            scope.add(crumb)
        })
    }
    
    private func assert(withScopeBreadcrumbsCount count: Int, with hub: SentryHub) {
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"] as? [AnyHashable]
        XCTAssertNotNil(scopeBreadcrumbs)
        XCTAssertEqual(scopeBreadcrumbs?.count, count)
    }
}
