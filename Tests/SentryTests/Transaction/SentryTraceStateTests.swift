import XCTest

class SentryTraceContextTests: SentryBaseUnitTest {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    
    private class Fixture {
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        let options: Options
        let scope: Scope
        let tracer: SentryTracer
        let userId = "SomeUserID"
        let userSegment = "Test Segment"
        let sampleRate = "0.45"
        let traceId: SentryId
        let publicKey = "SentrySessionTrackerTests"
        let releaseName = "SentrySessionTrackerIntegrationTests"
        let environment = "debug"
        
        init() {
            options = Options()
            options.dsn = SentryTraceContextTests.dsnAsString
            options.releaseName = releaseName
            options.environment = environment
            options.sendDefaultPii = true
            
            tracer = SentryTracer(transactionContext: TransactionContext(name: transactionName, operation: transactionOperation), hub: nil)
            
            scope = Scope()
            scope.setUser(SentryUser(userId: userId))
            scope.userObject?.segment = userSegment
            scope.span = tracer
            
            traceId = tracer.context.traceId
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testInit() {
        let traceContext = SentryTraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            userSegment: fixture.userSegment,
            sampleRate: fixture.sampleRate)
        
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
    
    func test_toBaggage() {
        let traceContext = SentryTraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            userSegment: fixture.userSegment,
            sampleRate: fixture.sampleRate)
        
        let baggage = traceContext.toBaggage()
        
        XCTAssertEqual(baggage.traceId, fixture.traceId)
        XCTAssertEqual(baggage.publicKey, fixture.publicKey)
        XCTAssertEqual(baggage.releaseName, fixture.releaseName)
        XCTAssertEqual(baggage.environment, fixture.environment)
        XCTAssertEqual(baggage.userSegment, fixture.userSegment)
        XCTAssertEqual(baggage.sampleRate, fixture.sampleRate)
    }
        
    func assertTraceState(traceContext: SentryTraceContext) {
        XCTAssertEqual(traceContext.traceId, fixture.traceId)
        XCTAssertEqual(traceContext.publicKey, fixture.publicKey)
        XCTAssertEqual(traceContext.releaseName, fixture.releaseName)
        XCTAssertEqual(traceContext.environment, fixture.environment)
        XCTAssertEqual(traceContext.transaction, fixture.transactionName)
        XCTAssertEqual(traceContext.userSegment, fixture.userSegment)
    }
    
}
