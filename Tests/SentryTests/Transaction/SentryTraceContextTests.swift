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
        let sampleRand = "0.6543"
        let sampleRate = "0.45"
        let traceId: SentryId
        let publicKey = "SentrySessionTrackerTests"
        let releaseName = "SentrySessionTrackerIntegrationTests"
        let environment = "debug"
        let sampled = "true"
        let replayId = "some_replay_id"
        
        init() {
            options = Options()
            options.dsn = SentryTraceContextTests.dsnAsString
            options.releaseName = releaseName
            options.environment = environment
            options.sendDefaultPii = true
            
            tracer = SentryTracer(transactionContext: TransactionContext(name: transactionName, operation: transactionOperation, sampled: .yes, sampleRate: nil, sampleRand: nil), hub: nil)

            scope = Scope()
            scope.setUser(User(userId: userId))
            scope.span = tracer
            scope.replayId = replayId
            
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
        // Act
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
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
        let traceContext = TraceContext(trace: traceId, options: options, replayId: "replayId")
        
        // Assert
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
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
        let traceContext = TraceContext(trace: traceId, options: options, replayId: nil)
        
        // Assert
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
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
        XCTAssertEqual(baggage.sampleRate, fixture.sampleRate)
        XCTAssertEqual(baggage.sampled, fixture.sampled)
        XCTAssertEqual(baggage.sampleRand, fixture.sampleRand)
        XCTAssertEqual(baggage.replayId, fixture.replayId)
    }
    
    func testSerialize_whenAllValuesSet_shouldIncludeAllFields() {
        // Arrange
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: fixture.releaseName,
            environment: fixture.environment,
            transaction: fixture.transactionName,
            sampleRate: fixture.sampleRate,
            sampleRand: fixture.sampleRand,
            sampled: fixture.sampled,
            replayId: fixture.replayId
        )
        
        // Act
        let serialized = traceContext.serialize()
        
        // Assert
        XCTAssertEqual(serialized["trace_id"] as? String, fixture.traceId.sentryIdString)
        XCTAssertEqual(serialized["public_key"] as? String, fixture.publicKey)
        XCTAssertEqual(serialized["release"] as? String, fixture.releaseName)
        XCTAssertEqual(serialized["environment"] as? String, fixture.environment)
        XCTAssertEqual(serialized["transaction"] as? String, fixture.transactionName)
        XCTAssertEqual(serialized["sample_rate"] as? String, fixture.sampleRate)
        XCTAssertEqual(serialized["sample_rand"] as? String, fixture.sampleRand)
        XCTAssertEqual(serialized["sampled"] as? String, fixture.sampled)
        XCTAssertEqual(serialized["replay_id"] as? String, fixture.replayId)
    }
    
    func testSerialize_whenOnlyRequiredValuesSet_shouldOnlyIncludeRequiredFields() {
        // Arrange
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: nil,
            environment: nil,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: nil
        )

        // Act
        let serialized = traceContext.serialize()

        // Assert
        // Required fields must be present
        XCTAssertEqual(serialized["trace_id"] as? String, fixture.traceId.sentryIdString)
        XCTAssertEqual(serialized["public_key"] as? String, fixture.publicKey)

        // Optional fields should be absent
        XCTAssertNil(serialized["release"])
        XCTAssertNil(serialized["environment"])
        XCTAssertNil(serialized["transaction"])
        XCTAssertNil(serialized["sample_rate"])
        XCTAssertNil(serialized["sample_rand"])
        XCTAssertNil(serialized["sampled"])
        XCTAssertNil(serialized["replay_id"])
    }

    // MARK: - orgId tests

    func testInitWithTracer_whenDsnHasOrgId_shouldIncludeOrgId() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@o123.ingest.sentry.io/456"
        options.releaseName = fixture.releaseName
        options.environment = fixture.environment

        // -- Act --
        let traceContext = TraceContext(tracer: fixture.tracer, scope: fixture.scope, options: options)

        // -- Assert --
        XCTAssertEqual(traceContext?.orgId, "123")
    }

    func testInitWithTracer_whenExplicitOrgIdSet_shouldUseExplicitOrgId() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@o123.ingest.sentry.io/456"
        options.orgId = "999"
        options.releaseName = fixture.releaseName
        options.environment = fixture.environment

        // -- Act --
        let traceContext = TraceContext(tracer: fixture.tracer, scope: fixture.scope, options: options)

        // -- Assert --
        XCTAssertEqual(traceContext?.orgId, "999")
    }

    func testInitWithTraceIdOptions_shouldIncludeOrgId() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@o123.ingest.sentry.io/456"

        // -- Act --
        let traceContext = TraceContext(trace: SentryId(), options: options, replayId: nil)

        // -- Assert --
        XCTAssertEqual(traceContext.orgId, "123")
    }

    func testInitWithDict_whenOrgIdPresent_shouldParseOrgId() {
        // -- Arrange --
        let dict: [String: Any] = [
            "trace_id": SentryId().sentryIdString,
            "public_key": "test",
            "org_id": "456"
        ]

        // -- Act --
        let traceContext = TraceContext(dict: dict)

        // -- Assert --
        XCTAssertEqual(traceContext?.orgId, "456")
    }

    func testInitWithDict_whenOrgIdAbsent_shouldReturnNilOrgId() {
        // -- Arrange --
        let dict: [String: Any] = [
            "trace_id": SentryId().sentryIdString,
            "public_key": "test"
        ]

        // -- Act --
        let traceContext = TraceContext(dict: dict)

        // -- Assert --
        XCTAssertNil(traceContext?.orgId)
    }

    func testSerialize_whenOrgIdSet_shouldIncludeOrgId() {
        // -- Arrange --
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: nil,
            environment: nil,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: nil,
            orgId: "789"
        )

        // -- Act --
        let serialized = traceContext.serialize()

        // -- Assert --
        XCTAssertEqual(serialized["org_id"] as? String, "789")
    }

    func testSerialize_whenOrgIdNil_shouldNotIncludeOrgId() {
        // -- Arrange --
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: nil,
            environment: nil,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: nil,
            orgId: nil
        )

        // -- Act --
        let serialized = traceContext.serialize()

        // -- Assert --
        XCTAssertNil(serialized["org_id"])
    }

    func testToBaggage_shouldIncludeOrgId() {
        // -- Arrange --
        let traceContext = TraceContext(
            trace: fixture.traceId,
            publicKey: fixture.publicKey,
            releaseName: nil,
            environment: nil,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: nil,
            orgId: "321"
        )

        // -- Act --
        let baggage = traceContext.toBaggage()

        // -- Assert --
        XCTAssertEqual(baggage.orgId, "321")
    }
        
    private func assertTraceState(traceContext: TraceContext) {
        XCTAssertEqual(traceContext.traceId, fixture.traceId)
        XCTAssertEqual(traceContext.publicKey, fixture.publicKey)
        XCTAssertEqual(traceContext.releaseName, fixture.releaseName)
        XCTAssertEqual(traceContext.environment, fixture.environment)
        XCTAssertEqual(traceContext.transaction, fixture.transactionName)
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
        XCTAssertEqual(traceContext.sampled, expectedSampled, "Sampled does not match", file: file, line: line)
        XCTAssertEqual(traceContext.sampleRate, expectedSampleRate, "Sample Rate does not match", file: file, line: line)
        XCTAssertEqual(traceContext.sampleRand, expectedSampleRand, "Sample Rand does not match", file: file, line: line)
        XCTAssertEqual(traceContext.replayId, expectedReplayId, "Replay ID does not match", file: file, line: line)
    }
    
}
