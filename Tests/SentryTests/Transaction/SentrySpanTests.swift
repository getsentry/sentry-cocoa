import Nimble
@testable import Sentry
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
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let tracer = SentryTracer(context: SpanContext(operation: "TEST"), framesTracker: nil)
#else
        let tracer = SentryTracer(context: SpanContext(operation: "TEST"))
#endif

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
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: TestSentryCrashWrapper.sharedInstance(), andDispatchQueue: TestSentryDispatchQueueWrapper())
            return hub.startTransaction(name: someTransaction, operation: someOperation)
        }
        
        func getSutWithTracer() -> SentrySpan {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            return SentrySpan(tracer: tracer, context: SpanContext(operation: someOperation, sampled: .undecided), framesTracker: nil)
#else
            return SentrySpan(tracer: tracer, context: SpanContext(operation: someOperation, sampled: .undecided))
#endif
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
        
        wait(for: [expect], timeout: 1.0)
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
        
        wait(for: [expect], timeout: 1.0)
    }
    
    func testFinish() throws {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        
        span.finish()
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
        
        let lastEvent = try XCTUnwrap(client.captureEventWithScopeInvocations.invocations.first).event
        XCTAssertEqual(lastEvent.transaction, fixture.someTransaction)
        XCTAssertEqual(lastEvent.timestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.startTimestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.type, SentryEnvelopeItemTypeTransaction)
    }
    
    func testFinish_Custom_Timestamp() throws {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        
        let finishDate = Date(timeIntervalSinceNow: 6)
        
        span.timestamp = finishDate
        
        span.finish()
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, finishDate)
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
        
        let lastEvent = try XCTUnwrap(client.captureEventWithScopeInvocations.invocations.first).event
        XCTAssertEqual(lastEvent.transaction, fixture.someTransaction)
        XCTAssertEqual(lastEvent.timestamp, finishDate)
        XCTAssertEqual(lastEvent.startTimestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.type, SentryEnvelopeItemTypeTransaction)
    }

    func testFinishSpanWithDefaultTimestamp() {
        let span = fixture.getSutWithTracer()
        span.finish()

        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
    }

    func testFinishSpanWithCustomTimestamp() {
        let span = fixture.getSutWithTracer()
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
    
    func testFinishWithChild() throws {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        let childSpan = span.startChild(operation: fixture.someOperation)
        
        childSpan.finish()
        span.finish()
        
        let lastEvent = try XCTUnwrap(client.captureEventWithScopeInvocations.invocations.first).event
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

    func testSerialization_NoStacktraceFrames() {
        let span = fixture.getSutWithTracer()
        let serialization = span.serialize()

        XCTAssertEqual(2, (serialization["data"] as? [String: Any])?.count, "Only expected thread.name and thread.id in data.")
    }

    func testSerialization_withStacktraceFrames() {
        let span = fixture.getSutWithTracer()
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
        let span = fixture.getSutWithTracer()

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
    
    func testInit_DoesNotIntializeLocalMetricAggregator() {
        let sut = fixture.getSut()
        
        let serialized = sut.serialize()
        expect(serialized["_metrics_summary"]) == nil
    }
    
    func testLocalMetricsAggregator_GetsSerializedAsMetricsSummary() throws {
        let sut = fixture.getSutWithTracer()
        
        let aggregator = sut.getLocalMetricsAggregator()
        aggregator.add(type: .counter, key: "key", value: 1.0, unit: .none, tags: [:])
        
        let serialized = sut.serialize()
        
        let metricsSummary = try XCTUnwrap(serialized["_metrics_summary"] as? [String: [[String: Any]]])
        expect(metricsSummary.count) == 1
        
        let bucket = try XCTUnwrap(metricsSummary["c:key"])
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        expect(metric["min"] as? Double) == 1.0
        expect(metric["max"] as? Double) == 1.0
        expect(metric["count"] as? Int) == 1
        expect(metric["sum"] as? Double) == 1.0
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
        let span = fixture.getSutWithTracer()
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.traceId)
        XCTAssertEqual(header.spanId, span.spanId)
        XCTAssertEqual(header.sampled, .undecided)
        XCTAssertEqual(header.value(), "\(span.traceId)-\(span.spanId)")
    }
    
    @available(*, deprecated)
    func testSetExtra_ForwardsToSetData() {
        let sut = fixture.getSutWithTracer()
        sut.setExtra(value: 0, key: "key")
        
        let data = sut.data as [String: Any]
        XCTAssertEqual(0, data["key"] as? Int)
    }
         
    func testSpanWithoutTracer_StartChild_ReturnsNoOpSpan() {
        // Span has a weak reference to tracer. If we don't keep a reference
        // to the tracer ARC will deallocate the tracer.
        let sutGenerator: () -> Span = {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            let tracer = SentryTracer(context: SpanContext(operation: "TEST"), framesTracker: nil)
            return SentrySpan(tracer: tracer, context: SpanContext(operation: ""), framesTracker: nil)
#else
            let tracer = SentryTracer(context: SpanContext(operation: "TEST"))
            return SentrySpan(tracer: tracer, context: SpanContext(operation: ""))
#endif
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
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testAddSlowFrozenFramesToData() {
        let (displayLinkWrapper, framesTracker) = givenFramesTracker()
        
        let sut = SentrySpan(context: SpanContext(operation: "TEST"), framesTracker: framesTracker)
        
        let slow = 2
        let frozen = 1
        let normal = 100
        displayLinkWrapper.renderFrames(slow, frozen, normal)
        
        sut.finish()
        
        expect(sut.data["frames.total"] as? NSNumber) == NSNumber(value: slow + frozen + normal)
        expect(sut.data["frames.slow"] as? NSNumber) == NSNumber(value: slow)
        expect(sut.data["frames.frozen"] as? NSNumber) == NSNumber(value: frozen)
    }
    
    func testDontAddAllZeroSlowFrozenFramesToData() {
        let (_, framesTracker) = givenFramesTracker()
        
        let sut = SentrySpan(context: SpanContext(operation: "TEST"), framesTracker: framesTracker)
        
        sut.finish()
        
        expect(sut.data["frames.total"]) == nil
        expect(sut.data["frames.slow"]) == nil
        expect(sut.data["frames.frozen"]) == nil
    }
    
    func testAddFrameStatisticsToData_WithPreexistingCounts() {
        let (displayLinkWrapper, framesTracker) = givenFramesTracker()
        let preexistingSlow = 1
        let preexistingFrozen = 2
        let preexistingNormal = 3
        displayLinkWrapper.renderFrames(preexistingSlow, preexistingFrozen, preexistingNormal)
        
        let sut = SentrySpan(context: SpanContext(operation: "TEST"), framesTracker: framesTracker)
        
        let slowFrames = 1
        let frozenFrames = 1
        let normalFrames = 100
        let totalFrames = slowFrames + frozenFrames + normalFrames
        _ = displayLinkWrapper.slowestSlowFrame()
        _ = displayLinkWrapper.fastestFrozenFrame()
        displayLinkWrapper.renderFrames(0, 0, normalFrames)
        
        sut.finish()
        
        expect(sut.data["frames.total"] as? NSNumber) == NSNumber(value: totalFrames)
        expect(sut.data["frames.slow"] as? NSNumber) == NSNumber(value: slowFrames)
        expect(sut.data["frames.frozen"] as? NSNumber) == NSNumber(value: frozenFrames)
        
        let expectedFrameDuration = slowFrameThreshold(displayLinkWrapper.currentFrameRate.rawValue)
        let expectedDelay = displayLinkWrapper.slowestSlowFrameDuration + displayLinkWrapper.fastestFrozenFrameDuration - expectedFrameDuration * 2 as NSNumber
        
        expect(sut.data["frames.delay"] as? NSNumber).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    func testNoFramesTracker_NoFramesAddedToData() {
        let sut = SentrySpan(context: SpanContext(operation: "TEST"), framesTracker: nil)
        
        sut.finish()
        
        expect(sut.data["frames.total"]) == nil
        expect(sut.data["frames.slow"]) == nil
        expect(sut.data["frames.frozen"]) == nil
        expect(sut.data["frames.delay"]) == nil
    }
    
    private func givenFramesTracker() -> (TestDisplayLinkWrapper, SentryFramesTracker) {
        let displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: self.fixture.currentDateProvider)
        let framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: self.fixture.currentDateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(), keepDelayedFramesDuration: 10)
        framesTracker.start()
        displayLinkWrapper.call()
        
        return (displayLinkWrapper, framesTracker)
    }
#endif
}
