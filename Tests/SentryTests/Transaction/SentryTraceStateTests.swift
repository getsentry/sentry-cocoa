import XCTest

class SentryTraceContextTests: XCTestCase {
    
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
            options.dsn = SentryTraceContextTests.dsnAsString
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
        let traceContext = SentryTraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            user: SentryTraceContextUser(userId: fixture.userId, segment: fixture.userSegment))
        
        assertTraceState(traceContext: traceContext)
    }
    
    func testInitWithScopeOptions() {
        let traceContext = SentryTraceContext(scope: fixture.scope, options: fixture.options)!
        
        assertTraceState(traceContext: traceContext)
    }
    
    func testInitWithTracerScopeOptions() {
        let traceContext = SentryTraceContext(tracer: fixture.tracer, scope: fixture.scope, options: fixture.options)
        
        assertTraceState(traceContext: traceContext!)
    }
    
    func testInitNil() {
        fixture.scope.span = nil
        let traceContext = SentryTraceContext(scope: fixture.scope, options: fixture.options)
        XCTAssertNil(traceContext)
    }
    
    func testUserSegment() {
        var traceContext = SentryTraceContext(scope: fixture.scope, options: fixture.options)
        XCTAssertNotNil(traceContext?.user?.segment)
        XCTAssertEqual(traceContext!.user!.segment, "Test Segment")
        fixture.scope.userObject?.data = ["segment": 5]
        traceContext = SentryTraceContext(scope: fixture.scope, options: fixture.options)
        XCTAssertNil(traceContext?.user?.segment)
    }
    
    func assertTraceState(traceContext: SentryTraceContext) {
        XCTAssertEqual(traceContext.traceId, fixture.traceId)
        XCTAssertEqual(traceContext.publicKey, fixture.publicKey)
        XCTAssertEqual(traceContext.releaseName, fixture.releaseName)
        XCTAssertEqual(traceContext.environment, fixture.environment)
        XCTAssertEqual(traceContext.transaction, fixture.transactionName)
        XCTAssertNotNil(traceContext.user)
        XCTAssertEqual(traceContext.user?.userId, fixture.userId)
        XCTAssertEqual(traceContext.user?.segment, fixture.userSegment)
    }
    
}
