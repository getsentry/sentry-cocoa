import Sentry
import SentryTestUtils
import XCTest

class SentrySpanTests: XCTestCase {
    private var logOutput: TestLogOutput!
    private var fixture: Fixture!

    private class Fixture {
        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let someDescription = "Some Description"
        let extraKey = "extra_key"
        let extraValue = "extra_value"
        let options: Options
        let currentDateProvider = TestCurrentDateProvider()
        let tracer = SentryTracer(context: SpanContext(operation: "TEST"))

        init() {
            options = Options()
            options.tracesSampleRate = 1
            options.dsn = TestConstants.dsnAsString(username: "username")
            options.environment = "test"
            currentDateProvider.setDate(date: TestData.timestamp)
        }
        
        func getSut() -> Span {
            return getSut(client: TestClient(options: options)!)
        }
        
        func getSut(client: SentryClient) -> Span {
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: TestSentryCrashWrapper.sharedInstance())
            return hub.startTransaction(name: someTransaction, operation: someOperation)
        }
        
    }
    
    override func setUp() {
        super.setUp()

        logOutput = TestLogOutput()
        SentryLog.configure(true, diagnosticLevel: SentryLevel.debug)
        SentryLog.setLogOutput(logOutput)

        fixture = Fixture()
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.currentDateProvider
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInitAndCheckForTimestamps() {
        let span = fixture.getSut()
        XCTAssertNotNil(span.startTimestamp)
        XCTAssertNil(span.timestamp)
        XCTAssertFalse(span.isFinished)
    }
    
    func testInit_SetsMainThreadInfoAsSpanData() {
        let span = fixture.getSut()
        XCTAssertEqual("main", span.data["thread.name"] as! String)
        
        let threadId = sentrycrashthread_self()
        XCTAssertEqual(NSNumber(value: threadId), span.data["thread.id"] as! NSNumber)
    }
    
    func testInit_SetsThreadInfoAsSpanData_FromBackgroundThread() {
        let expect = expectation(description: "Thread must be called.")
        
        Thread.detachNewThread {
            let threadName = "test-thread-name"
            Thread.current.name = threadName
            
            let span = self.fixture.getSut()
            XCTAssertEqual(threadName, span.data["thread.name"] as! String)
            let threadId = sentrycrashthread_self()
            XCTAssertEqual(NSNumber(value: threadId), span.data["thread.id"] as! NSNumber)
            
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 0.1)
    }
    
    func testInit_SetsThreadInfoAsSpanData_FromBackgroundThreadWithNoName() {
        let expect = expectation(description: "Thread must be called.")
        
        Thread.detachNewThread {
            Thread.current.name = ""
            
            let span = self.fixture.getSut()
            XCTAssertNil(span.data["thread.name"])
            let threadId = sentrycrashthread_self()
            XCTAssertEqual(NSNumber(value: threadId), span.data["thread.id"] as! NSNumber)
            
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 0.1)
    }
    
    func testFinish() {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        
        span.finish()
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
        
        let lastEvent = client.captureEventWithScopeInvocations.invocations[0].event
        XCTAssertEqual(lastEvent.transaction, fixture.someTransaction)
        XCTAssertEqual(lastEvent.timestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.startTimestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.type, SentryEnvelopeItemTypeTransaction)
    }
    
    func testFinish_Custom_Timestamp() {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        
        let finishDate = Date(timeIntervalSinceNow: 6)
        
        span.timestamp = finishDate
        
        span.finish()
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, finishDate)
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
        
        let lastEvent = client.captureEventWithScopeInvocations.invocations[0].event
        XCTAssertEqual(lastEvent.transaction, fixture.someTransaction)
        XCTAssertEqual(lastEvent.timestamp, finishDate)
        XCTAssertEqual(lastEvent.startTimestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.type, SentryEnvelopeItemTypeTransaction)
    }

    func testFinishSpanWithDefaultTimestamp() {
        let span = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: fixture.someOperation, sampled: .undecided))
        span.finish()

        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
    }

    func testFinishSpanWithCustomTimestamp() {
        let span = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: fixture.someOperation, sampled: .undecided))
        span.timestamp = Date(timeIntervalSince1970: 123)
        span.finish()

        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 123))
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
    }
    
    func testFinishWithStatus() {
        let span = fixture.getSut()
        span.finish(status: .cancelled)
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertEqual(span.status, .cancelled)
        XCTAssertTrue(span.isFinished)
    }
    
    func testFinishWithChild() {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        let childSpan = span.startChild(operation: fixture.someOperation)
        
        childSpan.finish()
        span.finish()
        
        let lastEvent = client.captureEventWithScopeInvocations.invocations[0].event
        let serializedData = lastEvent.serialize()
        
        let spans = serializedData["spans"] as! [Any]
        let serializedChild = spans[0] as! [String: Any]
        
        XCTAssertEqual(serializedChild["span_id"] as? String, childSpan.spanId.sentrySpanIdString)
        XCTAssertEqual(serializedChild["parent_span_id"] as? String, span.spanId.sentrySpanIdString)
    }
    
    func testStartChildWithNameOperation() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation)
        XCTAssertEqual(childSpan.parentSpanId, span.spanId)
        XCTAssertEqual(childSpan.operation, fixture.someOperation)
        XCTAssertNil(childSpan.spanDescription)
    }
    
    func testStartChildWithNameOperationAndDescription() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation, description: fixture.someDescription)
        
        XCTAssertEqual(childSpan.parentSpanId, span.spanId)
        XCTAssertEqual(childSpan.operation, fixture.someOperation)
        XCTAssertEqual(childSpan.spanDescription, fixture.someDescription)
    }

    func testStartChildOnFinishedSpan() {
        let span = fixture.getSut()
        span.finish()

        let childSpan = span.startChild(operation: fixture.someOperation, description: fixture.someDescription)

        XCTAssertNil(childSpan.parentSpanId)
        XCTAssertEqual(childSpan.operation, "")
        XCTAssertNil(childSpan.spanDescription)
        XCTAssertFalse(logOutput.loggedMessages.filter({ $0.contains(" Starting a child on a finished span is not supported; it won\'t be sent to Sentry.") }).isEmpty)
    }

    func testStartGrandChildOnFinishedSpan() {
        let span = fixture.getSut()
        let childSpan = span.startChild(operation: fixture.someOperation)
        childSpan.finish()
        span.finish()

        let grandChild = childSpan.startChild(operation: fixture.someOperation, description: fixture.someDescription)
        XCTAssertNil(grandChild.parentSpanId)
        XCTAssertEqual(grandChild.operation, "")
        XCTAssertNil(grandChild.spanDescription)
        XCTAssertFalse(logOutput.loggedMessages.filter({ $0.contains(" Starting a child on a finished span is not supported; it won\'t be sent to Sentry.") }).isEmpty)
    }
    
    func testAddAndRemoveData() {
        let span = fixture.getSut()

        span.setData(value: fixture.extraValue, key: fixture.extraKey)
        
        XCTAssertEqual(span.data.count, 3)
        XCTAssertEqual(span.data[fixture.extraKey] as! String, fixture.extraValue)
        
        span.removeData(key: fixture.extraKey)
        XCTAssertEqual(span.data.count, 2, "Only expected thread.name and thread.id in data.")
        XCTAssertNil(span.data[fixture.extraKey])
    }
    
    func testAddAndRemoveTags() {
        let span = fixture.getSut()
        
        span.setTag(value: fixture.extraValue, key: fixture.extraKey)
        
        XCTAssertEqual(span.tags.count, 1)
        XCTAssertEqual(span.tags[fixture.extraKey], fixture.extraValue)
        
        span.removeTag(key: fixture.extraKey)
        XCTAssertEqual(span.tags.count, 0)
        XCTAssertNil(span.tags[fixture.extraKey])
    }
    
    func testSerialization() {
        let span = fixture.getSut()
        
        span.setData(value: fixture.extraValue, key: fixture.extraKey)
        span.setTag(value: fixture.extraValue, key: fixture.extraKey)
        span.finish()
        
        //Faking extra info to test serialization
        span.parentSpanId = SpanId()
        span.spanDescription = "Span Description"

        let serialization = span.serialize()
        XCTAssertEqual(serialization["span_id"] as? String, span.spanId.sentrySpanIdString)
        XCTAssertEqual(serialization["parent_span_id"] as? String, span.parentSpanId?.sentrySpanIdString)
        XCTAssertEqual(serialization["trace_id"] as? String, span.traceId.sentryIdString)
        XCTAssertEqual(serialization["op"] as? String, span.operation)
        XCTAssertEqual(serialization["description"] as? String, span.spanDescription)
        XCTAssertEqual(serialization["status"] as? String, nameForSentrySpanStatus(span.status))
        XCTAssertEqual(serialization["sampled"] as? NSNumber, valueForSentrySampleDecision(span.sampled))
        XCTAssertEqual(serialization["timestamp"] as? TimeInterval, TestData.timestamp.timeIntervalSince1970)
        XCTAssertEqual(serialization["start_timestamp"] as? TimeInterval, TestData.timestamp.timeIntervalSince1970)
        XCTAssertEqual(serialization["type"] as? String, SENTRY_TRACE_TYPE)
        XCTAssertEqual(serialization["sampled"] as? NSNumber, true)
        XCTAssertNotNil(serialization["data"])
        XCTAssertNotNil(serialization["tags"])
        
        let data = serialization["data"] as? [String: Any]
        XCTAssertEqual(data?[fixture.extraKey] as! String, fixture.extraValue)
        XCTAssertEqual((serialization["tags"] as! Dictionary)[fixture.extraKey], fixture.extraValue)
        XCTAssertEqual("manual", serialization["origin"] as? String)
    }

    func testSerialization_NoFrames() {
        let span = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: "test"))
        let serialization = span.serialize()

        XCTAssertEqual(2, (serialization["data"] as? [String: Any])?.count, "Only expected thread.name and thread.id in data.")
    }

    func testSerialization_withFrames() {
        let span = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: "test"))
        span.frames = [TestData.mainFrame, TestData.testFrame]

        let serialization = span.serialize()

        XCTAssertNotNil(serialization["data"])
        let callStack = (serialization["data"] as? [String: Any])?["call_stack"] as? [[String: Any]]
        XCTAssertNotNil(callStack)
        XCTAssertEqual(callStack?.first?["function"] as? String, TestData.mainFrame.function)
        XCTAssertEqual(callStack?.last?["function"] as? String, TestData.testFrame.function)
    }

    func testSanitizeData() {
        let span = fixture.getSut()

        span.setData(value: Date(timeIntervalSince1970: 10), key: "date")
        span.finish()

        let serialization = span.serialize()
        let data = serialization["data"] as? [String: Any]
        XCTAssertEqual(data?["date"] as? String, "1970-01-01T00:00:10.000Z")
    }

    func testSanitizeDataSpan() {
        let span = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: fixture.someOperation, sampled: .undecided))

        span.setData(value: Date(timeIntervalSince1970: 10), key: "date")
        span.finish()

        let serialization = span.serialize()
        let data = serialization["data"] as? [String: Any]
        XCTAssertEqual(data?["date"] as? String, "1970-01-01T00:00:10.000Z")
    }
    
    func testSerialization_WithNoDataAndTag() {
        let span = fixture.getSut()
        
        let serialization = span.serialize()
        XCTAssertEqual(2, (serialization["data"] as? [String: Any])?.count, "Only expected thread.name and thread.id in data.")
        XCTAssertNil(serialization["tag"])
    }
    
    func testTraceHeaderNotSampled() {
        fixture.options.tracesSampleRate = 0
        let span = fixture.getSut()
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.traceId)
        XCTAssertEqual(header.spanId, span.spanId)
        XCTAssertEqual(header.sampled, .no)
        XCTAssertEqual(header.value(), "\(span.traceId)-\(span.spanId)-0")
    }
    
    func testTraceHeaderSampled() {
        fixture.options.tracesSampleRate = 1
        let span = fixture.getSut()
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.traceId)
        XCTAssertEqual(header.spanId, span.spanId)
        XCTAssertEqual(header.sampled, .yes)
        XCTAssertEqual(header.value(), "\(span.traceId)-\(span.spanId)-1")
    }
    
    func testTraceHeaderUndecided() {
        let span = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: fixture.someOperation, sampled: .undecided))
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.traceId)
        XCTAssertEqual(header.spanId, span.spanId)
        XCTAssertEqual(header.sampled, .undecided)
        XCTAssertEqual(header.value(), "\(span.traceId)-\(span.spanId)")
    }
    
    @available(*, deprecated)
    func testSetExtra_ForwardsToSetData() {
        let sut = SentrySpan(tracer: fixture.tracer, context: SpanContext(operation: "test"))
        sut.setExtra(value: 0, key: "key")
        
        let data = sut.data as [String: Any]
        XCTAssertEqual(0, data["key"] as? Int)
    }
         
    func testSpanWithoutTracer_StartChild_ReturnsNoOpSpan() {
        // Span has a weak reference to tracer. If we don't keep a reference
        // to the tracer ARC will deallocate the tracer.
        let sutGenerator: () -> Span = {
            let tracer = SentryTracer(context: SpanContext(operation: "TEST"))
            return SentrySpan(tracer: tracer, context: SpanContext(operation: ""))
        }
        
        let sut = sutGenerator()

        let actual = sut.startChild(operation: fixture.someOperation)
        XCTAssertTrue(SentryNoOpSpan.shared() === actual)
        
        let actualWithDescription = sut.startChild(operation: fixture.someOperation, description: fixture.someDescription)
        XCTAssertTrue(SentryNoOpSpan.shared() === actualWithDescription)
    }
    
    func testModifyingExtraFromMultipleThreads() {
        let queue = DispatchQueue(label: "SentrySpanTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
                
        let span = fixture.getSut()
        
        // The number is kept small for the CI to not take to long.
        // If you really want to test this increase to 100_000 or so.
        let innerLoop = 1_000
        let outerLoop = 20
        let value = fixture.extraValue
        
        for i in 0..<outerLoop {
            group.enter()
            queue.async {
                
                for j in 0..<innerLoop {
                    span.setData(value: value, key: "\(i)-\(j)")
                    span.setTag(value: value, key: "\(i)-\(j)")
                }
                
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        let threadDataItemCount = 2
        XCTAssertEqual(span.data.count, outerLoop * innerLoop + threadDataItemCount)
    }

    func testSpanStatusNames() {
        XCTAssertEqual(nameForSentrySpanStatus(.undefined), kSentrySpanStatusNameUndefined)
        XCTAssertEqual(nameForSentrySpanStatus(.ok), kSentrySpanStatusNameOk)
        XCTAssertEqual(nameForSentrySpanStatus(.deadlineExceeded), kSentrySpanStatusNameDeadlineExceeded)
        XCTAssertEqual(nameForSentrySpanStatus(.unauthenticated), kSentrySpanStatusNameUnauthenticated)
        XCTAssertEqual(nameForSentrySpanStatus(.permissionDenied), kSentrySpanStatusNamePermissionDenied)
        XCTAssertEqual(nameForSentrySpanStatus(.notFound), kSentrySpanStatusNameNotFound)
        XCTAssertEqual(nameForSentrySpanStatus(.resourceExhausted), kSentrySpanStatusNameResourceExhausted)
        XCTAssertEqual(nameForSentrySpanStatus(.invalidArgument), kSentrySpanStatusNameInvalidArgument)
        XCTAssertEqual(nameForSentrySpanStatus(.unimplemented), kSentrySpanStatusNameUnimplemented)
        XCTAssertEqual(nameForSentrySpanStatus(.unavailable), kSentrySpanStatusNameUnavailable)
        XCTAssertEqual(nameForSentrySpanStatus(.internalError), kSentrySpanStatusNameInternalError)
        XCTAssertEqual(nameForSentrySpanStatus(.unknownError), kSentrySpanStatusNameUnknownError)
        XCTAssertEqual(nameForSentrySpanStatus(.cancelled), kSentrySpanStatusNameCancelled)
        XCTAssertEqual(nameForSentrySpanStatus(.alreadyExists), kSentrySpanStatusNameAlreadyExists)
        XCTAssertEqual(nameForSentrySpanStatus(.failedPrecondition), kSentrySpanStatusNameFailedPrecondition)
        XCTAssertEqual(nameForSentrySpanStatus(.aborted), kSentrySpanStatusNameAborted)
        XCTAssertEqual(nameForSentrySpanStatus(.outOfRange), kSentrySpanStatusNameOutOfRange)
        XCTAssertEqual(nameForSentrySpanStatus(.dataLoss), kSentrySpanStatusNameDataLoss)
    }
}
