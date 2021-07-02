@testable import Sentry
import XCTest

// 0x7fc9a4920b40
class SentrySwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        let options = Options()
        options.dsn = "https://username:password@app.getsentry.com/12345"
        let fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider())
        fileManager.deleteAllEnvelopes()
        fileManager.deleteAllFolders()
        SentrySDK.start(options: options)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
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
        
        let event2 = Event(level: .debug)
        let scope = Sentry.Scope()
        scope.setExtras(["a": "b"])
        client!.capture(event: event2, scope: scope)
    }
    
    func testEnabled() {
        let options = try! Sentry.Options(dict: ["dsn": "https://username:password@app.getsentry.com/12345", "enabled": true])

        let client = Client(options: options)
        SentrySDK.currentHub().bindClient(client)
        XCTAssertNotNil(client)
        
        let event2 = Event(level: .debug)
        let scope = Sentry.Scope()
        scope.setExtras(["a": "b"])
        client!.capture(event: event2, scope: scope)
    }
    
    func testFunctionCalls() {
        let event = Event(level: .debug)
        event.message = SentryMessage(formatted: "Test Message")
    
        event.environment = "staging"
        let scope = Sentry.Scope()
        scope.setExtras(["ios": true])
        XCTAssertNotNil(event.serialize())
        SentrySDK.start { options in
            options.dsn = "https://username:password@app.getsentry.com/12345"
        }
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
    }
}
