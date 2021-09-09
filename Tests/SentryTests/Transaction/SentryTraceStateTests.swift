import XCTest

class SentryTraceStateTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    
    private class Fixture {
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        let options: Options
        let scope: Scope
        let tracer: SentryTracer
        let userId = "SomeUserID"
        let userSegment = "Test Segment"
        let traceId: SentryId
        let publicKey = "SentrySessionTrackerTests"
        let releaseName = "SentrySessionTrackerIntegrationTests"
        let environment = "debug"
        
        init() {
            options = Options()
            options.dsn = SentryTraceStateTests.dsnAsString
            options.releaseName = releaseName
            options.environment = environment
            
            tracer = SentryTracer(transactionContext: TransactionContext(name: transactionName, operation: transactionOperation), hub: nil)
            
            scope = Scope()
            scope.setUser(User(userId: userId))
            scope.userObject?.data = ["segment": "Test Segment"]
            scope.span = tracer
            
            traceId = tracer.context.traceId
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInit() {
        let traceState = SentryTraceState(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            user: SentryTraceStateUser(userId: fixture.userId, segment: fixture.userSegment))
        
        assertTraceState(traceState: traceState)
    }
    
    func testInitWithScopeOptions() {
        let traceState = SentryTraceState(scope: fixture.scope, options: fixture.options)!
        
        assertTraceState(traceState: traceState)
    }
    
    func testInitWithTracerScopeOptions() {
        let traceState = SentryTraceState(tracer: fixture.tracer, scope: fixture.scope, options: fixture.options)
        
        assertTraceState(traceState: traceState!)
    }
    
    func testInitNil() {
        fixture.scope.span = nil
        let traceState = SentryTraceState(scope: fixture.scope, options: fixture.options)
        XCTAssertNil(traceState)
    }
    
    func testUserSegment() {
        var traceState = SentryTraceState(scope: fixture.scope, options: fixture.options)
        XCTAssertNotNil(traceState?.user?.segment)
        XCTAssertEqual(traceState!.user!.segment, "Test Segment")
        fixture.scope.userObject?.data = ["segment": 5]
        traceState = SentryTraceState(scope: fixture.scope, options: fixture.options)
        XCTAssertNil(traceState?.user?.segment)
    }
    
    func assertTraceState(traceState: SentryTraceState) {
        XCTAssertEqual(traceState.traceId, fixture.traceId)
        XCTAssertEqual(traceState.publicKey, fixture.publicKey)
        XCTAssertEqual(traceState.releaseName, fixture.releaseName)
        XCTAssertEqual(traceState.environment, fixture.environment)
        XCTAssertEqual(traceState.transaction, fixture.transactionName)
        XCTAssertNotNil(traceState.user)
        XCTAssertEqual(traceState.user?.userId, fixture.userId)
        XCTAssertEqual(traceState.user?.segment, fixture.userSegment)
    }
    
}
