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
        assertFullTraceState(
            traceContext: traceContext,
            expectedTraceId: fixture.traceId,
            expectedPublicKey: fixture.publicKey,
            expectedReleaseName: fixture.releaseName,
            expectedEnvironment: fixture.environment,
            expectedTransaction: fixture.transactionName,
            expectedUserSegment: fixture.userSegment,
            expectedSampled: fixture.sampled,
            expectedSampleRate: fixture.sampleRate,
            expectedSampleRand: fixture.sampleRand,
            expectedReplayId: fixture.replayId
        )
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
        
    private func assertTraceState(traceContext: TraceContext) {
        XCTAssertEqual(traceContext.traceId, fixture.traceId)
        XCTAssertEqual(traceContext.publicKey, fixture.publicKey)
        XCTAssertEqual(traceContext.releaseName, fixture.releaseName)
        XCTAssertEqual(traceContext.environment, fixture.environment)
        XCTAssertEqual(traceContext.transaction, fixture.transactionName)
        XCTAssertEqual(traceContext.userSegment, fixture.userSegment)
        XCTAssertEqual(traceContext.sampled, fixture.sampled)
        XCTAssertEqual(traceContext.replayId, fixture.replayId)
    }

    private func assertFullTraceState(
        traceContext: TraceContext,
        expectedTraceId: SentryId,
        expectedPublicKey: String,
        expectedReleaseName: String,
        expectedEnvironment: String,
        expectedTransaction: String,
        expectedUserSegment: String,
        expectedSampled: String,
        expectedSampleRate: String,
        expectedSampleRand: String,
        expectedReplayId: String,
        file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(traceContext.traceId, expectedTraceId, "Trace ID does not match", file: file, line: line)
        XCTAssertEqual(traceContext.publicKey, expectedPublicKey, "Public Key does not match", file: file, line: line)
        XCTAssertEqual(traceContext.releaseName, expectedReleaseName, "Release Name does not match", file: file, line: line)
        XCTAssertEqual(traceContext.environment, expectedEnvironment, "Environment does not match", file: file, line: line)
        XCTAssertEqual(traceContext.transaction, expectedTransaction, "Transaction does not match", file: file, line: line)
        XCTAssertEqual(traceContext.userSegment, expectedUserSegment, "User Segment does not match", file: file, line: line)
        XCTAssertEqual(traceContext.sampled, expectedSampled, "Sampled does not match", file: file, line: line)
        XCTAssertEqual(traceContext.sampleRate, expectedSampleRate, "Sample Rate does not match", file: file, line: line)
        XCTAssertEqual(traceContext.sampleRand, expectedSampleRand, "Sample Rand does not match", file: file, line: line)
        XCTAssertEqual(traceContext.replayId, expectedReplayId, "Replay ID does not match", file: file, line: line)
    }
    
}
