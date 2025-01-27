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
        let sampleRand = "0.6543"
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
        // Act
        let traceContext = TraceContext(
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
        
        // Assert
        assertTraceState(traceContext: traceContext)
    }
    
    func testInit_withSampleRateRand() {
        // Act
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            userSegment: fixture.userSegment,
            sampleRate: fixture.sampleRate,
            sampleRand: fixture.sampleRand,
            sampled: fixture.sampled,
            replayId: fixture.replayId
        )
        
        // Assert
        assertTraceState(traceContext: traceContext)
    }
    
    func testInitWithScopeOptions() {
        // Act
        let traceContext = TraceContext(scope: fixture.scope, options: fixture.options)!
        
        // Assert
        assertTraceState(traceContext: traceContext)
    }
    
    func testInitWithTracerScopeOptions() {
        // Act
        let traceContext = TraceContext(tracer: fixture.tracer, scope: fixture.scope, options: fixture.options)
        
        // Assert
        assertTraceState(traceContext: traceContext!)
    }

    func testInitWithTracerNotSampled() {
        // Arrange
        let tracer = fixture.tracer
        tracer.sampled = .no
        
        // Act
        let traceContext = TraceContext(tracer: tracer, scope: fixture.scope, options: fixture.options)
        
        // Assert
        XCTAssertEqual(traceContext?.sampled, "false")
    }
    
    func testInitNil() {
        // Arrange
        fixture.scope.span = nil
        
        // Act
        let traceContext = TraceContext(scope: fixture.scope, options: fixture.options)
        
        // Assert
        XCTAssertNil(traceContext)
    }
    
    func testInitTraceIdOptionsSegment_WithOptionsAndSegment() throws {
        // Arrange
        let options = Options()
        options.dsn = TestConstants.realDSN
    
        let traceId = SentryId()
        
        // Act
        let traceContext = TraceContext(trace: traceId, options: options, userSegment: "segment", replayId: "replayId")
        
        // Assert
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
        XCTAssertEqual("segment", traceContext.userSegment)
        XCTAssertEqual(traceContext.replayId, "replayId")
        XCTAssertNil(traceContext.sampleRate)
        XCTAssertNil(traceContext.sampleRand)
        XCTAssertNil(traceContext.sampled)
    }
    
    func testInitTraceIdOptionsSegment_WithOptionsOnly() throws {
        // Arrange
        let options = Options()
        options.dsn = TestConstants.realDSN
    
        let traceId = SentryId()

        // Act
        let traceContext = TraceContext(trace: traceId, options: options, userSegment: nil, replayId: nil)
        
        // Assert
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
        XCTAssertNil(traceContext.userSegment)
        XCTAssertNil(traceContext.sampleRate)
        XCTAssertNil(traceContext.sampleRand)
        XCTAssertNil(traceContext.sampled)
    }
    
    func test_toBaggage() {
        // Arrange
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            userSegment: fixture.userSegment,
            sampleRate: fixture.sampleRate,
            sampleRand: fixture.sampleRand,
            sampled: fixture.sampled,
            replayId: fixture.replayId)
        
        // Act
        let baggage = traceContext.toBaggage()
        
        // Assert
        XCTAssertEqual(baggage.traceId, fixture.traceId)
        XCTAssertEqual(baggage.publicKey, fixture.publicKey)
        XCTAssertEqual(baggage.releaseName, fixture.releaseName)
        XCTAssertEqual(baggage.environment, fixture.environment)
        XCTAssertEqual(baggage.userSegment, fixture.userSegment)
        XCTAssertEqual(baggage.sampleRate, fixture.sampleRate)
        XCTAssertEqual(baggage.sampled, fixture.sampled)
        XCTAssertEqual(baggage.sampleRand, fixture.sampleRand)
        XCTAssertEqual(baggage.replayId, fixture.replayId)
    }
        
    func assertTraceState(traceContext: TraceContext, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(traceContext.traceId, fixture.traceId, file: file, line: line)
        XCTAssertEqual(traceContext.publicKey, fixture.publicKey, file: file, line: line)
        XCTAssertEqual(traceContext.releaseName, fixture.releaseName, file: file, line: line)
        XCTAssertEqual(traceContext.environment, fixture.environment, file: file, line: line)
        XCTAssertEqual(traceContext.transaction, fixture.transactionName, file: file, line: line)
        XCTAssertEqual(traceContext.userSegment, fixture.userSegment, file: file, line: line)
        XCTAssertEqual(traceContext.sampled, fixture.sampled, file: file, line: line)
        XCTAssertEqual(traceContext.sampleRate, fixture.sampleRate, file: file, line: line)
        XCTAssertEqual(traceContext.sampleRand, fixture.sampleRand, file: file, line: line)
        XCTAssertEqual(traceContext.replayId, fixture.replayId, file: file, line: line)
    }
    
}
