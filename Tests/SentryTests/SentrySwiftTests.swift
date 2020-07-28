@testable import Sentry
import XCTest

// 0x7fc9a4920b40
class SentrySwiftTests: XCTestCase {
    
    // swiftlint:disable force_unwrapping
    
    override func setUp() {
        super.setUp()
        let fileManager = try! SentryFileManager(dsn: SentryDsn(string: "https://username:password@app.getsentry.com/12345"), currentDateProvider: TestCurrentDateProvider())
        fileManager.deleteAllStoredEventsAndEnvelopes()
        fileManager.deleteAllFolders()
        _ = SentrySDK(options: ["dsn": "https://username:password@app.getsentry.com/12345"])
//        SentrySDK.init(options: ["dsn": "https://username:password@app.getsentry.com/12345"])
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testWrongDsn() {
        XCTAssertThrowsError(try Sentry.Options(dict: ["dsn": "http://sentry.io"]))
    }
    
    func testCorrectDsn() {
        let options = try? Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345"])
        XCTAssertNotNil(options)
    }
    
    func testOptions() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345"])

        let client = Client(options: options)
        XCTAssertNotNil(client)
    }
    
    func testDisabled() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345", "enabled": false])

        let client = Client(options: options)
        SentrySDK.currentHub().bindClient(client)
        XCTAssertNotNil(client)

//        client?.transport.beforeSendRequest = { request in
//            XCTAssertTrue(false)
//        }
        
        let event2 = Event(level: .debug)
        let scope = Sentry.Scope()
        scope.setExtras(["a": "b"])
        client!.capture(event: event2, scope: scope)
        //send(event: event2, scope: scope)
    }
    
    func testEnabled() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345", "enabled": true])

        let client = Client(options: options)
        SentrySDK.currentHub().bindClient(client)
        XCTAssertNotNil(client)
        
//        client?.transport.beforeSendRequest = { request in
//            XCTAssertTrue(true)
//        }
        
        let event2 = Event(level: .debug)
        let scope = Sentry.Scope()
        scope.setExtras(["a": "b"])
        client!.capture(event: event2, scope: scope)
        // TODO(fetzig) this thest used to have a callback
        // 1) check if we should keep/drop the callback
        // 2) update test accordingly

//        client!.send(event: event2, scope: scope) { (error) in
//            XCTAssertNil(error)
//        }
    }
    
    func testFunctionCalls() {
        let event = Event(level: .debug)
        event.message = "Test Message"
        event.environment = "staging"
        let scope = Sentry.Scope()
        scope.setExtras(["ios": true])
        XCTAssertNotNil(event.serialize())
        _ = SentrySDK(options: ["dsn": "https://username:password@app.getsentry.com/12345"])
        print("#####################")
        print(SentrySDK.currentHub().getClient() ?? "no client")

        SentrySDK.currentHub().getClient()!.capture(event: event, scope: scope)

        let event2 = Event(level: .debug)
        let scope2 = Sentry.Scope()
        scope2.setExtras(["a": "b"])
        XCTAssertNotNil(event2.serialize())

        SentrySDK.currentHub().getClient()?.options.beforeSend = { event in
            event.extra = ["b": "c"]
            return event
        }
        
        SentrySDK.currentHub().getClient()!.capture(event: event2, scope: scope)
        // TODO(fetzig) this thest used to have a callback
        // 1) check if we should keep/drop the callback
        // 2) update test accordingly

//        { (error) in
//            XCTAssertNil(error)
//        }
//
        //Client.logLevel = .debug
        // TODO(fetzig) reaplaced this with `bindClient:nil` but should reset scope as well. check how.
        //SentrySDK.currentHub().getClient()!.clearContext()
        SentrySDK.currentHub().bindClient(nil)
        // TODO(fetzig): check if this is the intended way to do this
//        SentrySDK.currentHub().configureScope { (scope) in
//            scope.breadcrumbs.maxBreadcrumbs = 100
//            scope.breadcrumbs.add(Breadcrumb(level: .info, category: "test"))
//        }
//        XCTAssertEqual(Client.shared?.breadcrumbs.count(), 1)
//        Client.shared?.enableAutomaticBreadcrumbTracking()
//        let user = User()
//        user.userId = "1234"
//        user.email = "hello@sentry.io"
//        user.extra = ["is_admin": true]
//        Client.shared?.user = user
//
//        Client.shared?.tags = ["iphone": "true"]
//
//        Client.shared?.clearContext()
//
//        Client.shared?.snapshotStacktrace {
//            let event = Event(level: .debug)
//            event.message = "Test Message"
//            Client.shared?.send(event: event)
//        }
//        Client.shared?.beforeSendRequest = { request in
//            request.addValue("my-token", forHTTPHeaderField: "Authorization")
//        }
    }
    
    // swiftlint:enable force_unwrapping
    
}
