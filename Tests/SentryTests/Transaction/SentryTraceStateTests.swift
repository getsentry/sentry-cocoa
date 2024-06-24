import Nimble
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
        let replayId = "some_replay_id"
        
        @available(*, deprecated)
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
            scope.replayId = replayId
            
            traceId = tracer.traceId
        }
    }
    
    private var fixture: Fixture!
    
    @available(*, deprecated)
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
            sampled: fixture.sampled,
            replayId: fixture.replayId
        )
        
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
            sampled: fixture.sampled,
            replayId: fixture.replayId)
        
        let baggage = traceContext.toBaggage()
        
        expect(baggage.traceId) == fixture.traceId
        expect(baggage.publicKey) == fixture.publicKey
        expect(baggage.releaseName) == fixture.releaseName
        expect(baggage.environment) == fixture.environment
        expect(baggage.userSegment) == fixture.userSegment
        expect(baggage.sampleRate) == fixture.sampleRate
        expect(baggage.sampled) == fixture.sampled
        expect(baggage.replayId) == fixture.replayId
    }
        
    func assertTraceState(traceContext: SentryTraceContext) {
        expect(traceContext.traceId) == fixture.traceId
        expect(traceContext.publicKey) == fixture.publicKey
        expect(traceContext.releaseName) == fixture.releaseName
        expect(traceContext.environment) == fixture.environment
        expect(traceContext.transaction) == fixture.transactionName
        expect(traceContext.userSegment) == fixture.userSegment
        expect(traceContext.sampled) == fixture.sampled
        expect(traceContext.replayId) == fixture.replayId
    }
    
}
