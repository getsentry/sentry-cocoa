@testable import Sentry
import XCTest

class SentryBuildAppStartSpansTests: XCTestCase {

    func testSentryBuildAppStartSpans_appStartMeasurementIsNil_shouldNotReturnAnySpans() {
        // Arrange
        let context = SpanContext(operation: "operation")
        let tracer = SentryTracer(context: context, framesTracker: nil)
        let appStartMeasurement: SentryAppStartMeasurement? = nil

        // Act
        let result = sentryBuildAppStartSpans(tracer, appStartMeasurement)

        // Assert
        XCTAssertEqual(result, [])
    }

    func testSentryBuildAppStartSpans_appStartMeasurementIsNotColdOrWarm_shouldNotReturnAnySpans() {
        // Arrange
        let context = SpanContext(operation: "operation")
        let tracer = SentryTracer(context: context, framesTracker: nil)
        let appStartMeasurement = SentryAppStartMeasurement(
            type: SentryAppStartType.unknown,
            isPreWarmed: false,
            appStartTimestamp: Date(timeIntervalSince1970: 1_000),
            runtimeInitSystemTimestamp: 1_100,
            duration: 1_200,
            runtimeInitTimestamp: Date(timeIntervalSince1970: 1_300),
            moduleInitializationTimestamp: Date(timeIntervalSince1970: 1_400),
            sdkStartTimestamp: Date(timeIntervalSince1970: 1_500),
            didFinishLaunchingTimestamp: Date(timeIntervalSince1970: 1_600)
        )

        // Act
        let result = sentryBuildAppStartSpans(tracer, appStartMeasurement)

        // Assert
        XCTAssertEqual(result, [])
    }

    func testSentryBuildAppStartSpans_appStartMeasurementIsColdAndNotPrewarmed_shouldNotIncludePreRuntimeSpans() {
        // Arrange
        let context = SpanContext(operation: "operation")
        let tracer = SentryTracer(context: context, framesTracker: nil)
        let appStartMeasurement = SentryAppStartMeasurement(
            type: SentryAppStartType.cold,
            isPreWarmed: false,
            appStartTimestamp: Date(timeIntervalSince1970: 1_000),
            runtimeInitSystemTimestamp: 1_100,
            duration: 935,
            runtimeInitTimestamp: Date(timeIntervalSince1970: 1_300),
            moduleInitializationTimestamp: Date(timeIntervalSince1970: 1_400),
            sdkStartTimestamp: Date(timeIntervalSince1970: 1_500),
            didFinishLaunchingTimestamp: Date(timeIntervalSince1970: 1_600)
        )

        // Act
        let result = sentryBuildAppStartSpans(tracer, appStartMeasurement)

        // Assert
        XCTAssertEqual(result.count, 6, "Number of spans do not match")
        assertSpan(
            span: result[0],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: tracer.spanId.sentrySpanIdString,
            expectedOperation: "app.start.cold",
            expectedDescription: "Cold Start",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_000),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_935),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[1],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.cold",
            expectedDescription: "Pre Runtime Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_000),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_300),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[2],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.cold",
            expectedDescription: "Runtime Init to Pre Main Initializers",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_300),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_400),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[3],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.cold",
            expectedDescription: "UIKit Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_400),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_500),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[4],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.cold",
            expectedDescription: "Application Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_500),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_600),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[5],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.cold",
            expectedDescription: "Initial Frame Render",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_600),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_935),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
    }

    func testSentryBuildAppStartSpans_appStartMeasurementIsWarmAndNotPrewarmed_shouldNotIncludePreRuntimeSpans() {
        // Arrange
        let context = SpanContext(operation: "operation")
        let tracer = SentryTracer(context: context, framesTracker: nil)
        let appStartMeasurement = SentryAppStartMeasurement(
            type: SentryAppStartType.warm,
            isPreWarmed: false,
            appStartTimestamp: Date(timeIntervalSince1970: 1_000),
            runtimeInitSystemTimestamp: 1_100,
            duration: 935,
            runtimeInitTimestamp: Date(timeIntervalSince1970: 1_300),
            moduleInitializationTimestamp: Date(timeIntervalSince1970: 1_400),
            sdkStartTimestamp: Date(timeIntervalSince1970: 1_500),
            didFinishLaunchingTimestamp: Date(timeIntervalSince1970: 1_600)
        )

        // Act
        let result = sentryBuildAppStartSpans(tracer, appStartMeasurement)

        // Assert
        XCTAssertEqual(result.count, 6, "Number of spans do not match")
        assertSpan(
            span: result[0],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: tracer.spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Warm Start",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_000),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_935),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[1],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Pre Runtime Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_000),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_300),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[2],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Runtime Init to Pre Main Initializers",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_300),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_400),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[3],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "UIKit Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_400),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_500),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[4],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Application Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_500),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_600),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[5],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Initial Frame Render",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_600),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_935),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
    }

    func testSentryBuildAppStartSpans_appStartMeasurementIsPreWarmed_shouldIncludePreRuntimeSpans() {
        // Arrange
        let context = SpanContext(operation: "operation")
        let tracer = SentryTracer(context: context, framesTracker: nil)
        let appStartMeasurement = SentryAppStartMeasurement(
            type: SentryAppStartType.warm,
            isPreWarmed: true,
            appStartTimestamp: Date(timeIntervalSince1970: 1_000),
            runtimeInitSystemTimestamp: 1_100,
            duration: 935,
            runtimeInitTimestamp: Date(timeIntervalSince1970: 1_300),
            moduleInitializationTimestamp: Date(timeIntervalSince1970: 1_400),
            sdkStartTimestamp: Date(timeIntervalSince1970: 1_500),
            didFinishLaunchingTimestamp: Date(timeIntervalSince1970: 1_600)
        )

        // Act
        let result = sentryBuildAppStartSpans(tracer, appStartMeasurement)

        // Assert
        XCTAssertEqual(result.count, 4, "Number of spans do not match")
        assertSpan(
            span: result[0],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: tracer.spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Warm Start",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_000),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_935),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[1],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "UIKit Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_400),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_500),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[2],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Application Init",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_500),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_600),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
        assertSpan(
            span: result[3],
            expectedTraceId: tracer.traceId.sentryIdString,
            expectedParentSpanId: result[0].spanId.sentrySpanIdString,
            expectedOperation: "app.start.warm",
            expectedDescription: "Initial Frame Render",
            expectedStartTimestamp: Date(timeIntervalSince1970: 1_600),
            expectedEndTimestamp: Date(timeIntervalSince1970: 1_935),
            expectedSampled: tracer.sampled,
            expectedSampleRate: tracer.sampleRate,
            expectedSampleRand: tracer.sampleRand
        )
    }

    func assertSpan(
        span: Span,
        expectedTraceId: String,
        expectedParentSpanId: String,
        expectedOperation: String,
        expectedDescription: String,
        expectedStartTimestamp: Date,
        expectedEndTimestamp: Date,
        expectedSampled: SentrySampleDecision,
        expectedSampleRate: NSNumber?,
        expectedSampleRand: NSNumber?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(span.traceId.sentryIdString, expectedTraceId, "TraceId does not match", file: file, line: line)
        XCTAssertEqual(span.parentSpanId?.sentrySpanIdString, expectedParentSpanId, "ParentSpanId does not match", file: file, line: line)
        XCTAssertEqual(span.operation, expectedOperation, "Operation does not match", file: file, line: line)
        XCTAssertEqual(span.spanDescription, expectedDescription, "Description does not match", file: file, line: line)
        XCTAssertEqual(span.startTimestamp, expectedStartTimestamp, "StartTimestamp does not match", file: file, line: line)
        XCTAssertEqual(span.timestamp, expectedEndTimestamp, "EndTimestamp does not match", file: file, line: line)
        XCTAssertEqual(span.sampled, expectedSampled, "Sampled does not match", file: file, line: line)
        XCTAssertEqual(span.sampleRate, expectedSampleRate, "SampleRate does not match", file: file, line: line)
        XCTAssertEqual(span.sampleRand, expectedSampleRand, "SampleRand does not match", file: file, line: line)
    }
}
