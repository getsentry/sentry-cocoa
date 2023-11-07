import SentryTestUtils
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
        let sampleRate = "0.45"
        let traceId: SentryId
        let publicKey = "SentrySessionTrackerTests"
        let releaseName = "SentrySessionTrackerIntegrationTests"
        let environment = "debug"
        let sampled = "true"
        
        init() {
            options = Options()
            options.dsn = SentryTraceContextTests.dsnAsString
            options.releaseName = releaseName
            options.environment = environment
            options.sendDefaultPii = true
            
            tracer = SentryTracer(transactionContext: TransactionContext(name: transactionName, operation: transactionOperation, sampled: .yes), hub: nil)

            scope = Scope()
            scope.setUser(User(userId: userId))
            scope.userObject?.segment = userSegment
            scope.span = tracer
            
            traceId = tracer.traceId
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
            userSegment: fixture.userSegment,
            sampleRate: fixture.sampleRate,
            sampled: fixture.sampled)
        
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

    func testInitWithTracerNotSampled() {
        let tracer = fixture.tracer
        tracer.sampled = .no
        let traceContext = SentryTraceContext(tracer: tracer, scope: fixture.scope, options: fixture.options)
        XCTAssertEqual(traceContext?.sampled, "false")
    }
    
    func testInitNil() {
        fixture.scope.span = nil
        let traceContext = SentryTraceContext(scope: fixture.scope, options: fixture.options)
        XCTAssertNil(traceContext)
    }
    
    func testInitTraceIdOptionsSegment_WithOptionsAndSegment() throws {
        let options = Options()
        options.dsn = TestConstants.realDSN
    
        let traceId = SentryId()
        let traceContext = SentryTraceContext(trace: traceId, options: options, userSegment: "segment")
        
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
        XCTAssertEqual("segment", traceContext.userSegment)
        XCTAssertNil(traceContext.sampleRate)
        XCTAssertNil(traceContext.sampled)
    }
    
    func testInitTraceIdOptionsSegment_WithOptionsOnly() throws {
        let options = Options()
        options.dsn = TestConstants.realDSN
    
        let traceId = SentryId()
        let traceContext = SentryTraceContext(trace: traceId, options: options, userSegment: nil)
        
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
        XCTAssertNil(traceContext.userSegment)
        XCTAssertNil(traceContext.sampleRate)
        XCTAssertNil(traceContext.sampled)
    }
    
    func test_toBaggage() {
        let traceContext = SentryTraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            userSegment: fixture.userSegment,
            sampleRate: fixture.sampleRate,
            sampled: fixture.sampled)
        
        let baggage = traceContext.toBaggage()
        
        XCTAssertEqual(baggage.traceId, fixture.traceId)
        XCTAssertEqual(baggage.publicKey, fixture.publicKey)
        XCTAssertEqual(baggage.releaseName, fixture.releaseName)
        XCTAssertEqual(baggage.environment, fixture.environment)
        XCTAssertEqual(baggage.userSegment, fixture.userSegment)
        XCTAssertEqual(baggage.sampleRate, fixture.sampleRate)
        XCTAssertEqual(baggage.sampled, fixture.sampled)
    }
        
    func assertTraceState(traceContext: SentryTraceContext) {
        XCTAssertEqual(traceContext.traceId, fixture.traceId)
        XCTAssertEqual(traceContext.publicKey, fixture.publicKey)
        XCTAssertEqual(traceContext.releaseName, fixture.releaseName)
        XCTAssertEqual(traceContext.environment, fixture.environment)
        XCTAssertEqual(traceContext.transaction, fixture.transactionName)
        XCTAssertEqual(traceContext.userSegment, fixture.userSegment)
        XCTAssertEqual(traceContext.sampled, fixture.sampled)
    }
    
}
