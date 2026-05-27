@import SentryObjC;
@import XCTest;

@interface SentryObjCTraceHeaderTests : XCTestCase
@end

@implementation SentryObjCTraceHeaderTests

#pragma mark - initWithTraceId:spanId:sampled:

- (void)testInit_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertNotNil(header);
}

- (void)testInit_shouldSetTraceId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqualObjects(header.traceId.sentryIdString, traceId.sentryIdString);
}

- (void)testInit_shouldSetSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqualObjects(header.spanId.sentrySpanIdString, spanId.sentrySpanIdString);
}

- (void)testInit_shouldSetSampled
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqual(header.sampled, SentryObjCSampleDecisionYes);
}

#pragma mark - value

- (void)testValue_shouldReturnNonEmptyString
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Act --
    NSString *value = [header value];

    // -- Assert --
    XCTAssertNotNil(value);
    XCTAssertTrue(value.length > 0);
}

- (void)testValue_shouldContainTraceId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Act --
    NSString *value = [header value];

    // -- Assert --
    XCTAssertTrue([value containsString:traceId.sentryIdString]);
}

- (void)testValue_shouldContainSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Act --
    NSString *value = [header value];

    // -- Assert --
    XCTAssertTrue([value containsString:spanId.sentrySpanIdString]);
}

#pragma mark - sampled variations

- (void)testSampled_whenNo_shouldReturnNo
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertEqual(header.sampled, SentryObjCSampleDecisionNo);
}

- (void)testValue_whenSampledNo_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Act --
    NSString *value = [header value];

    // -- Assert --
    XCTAssertNotNil(value);
}

- (void)testSampled_whenUndecided_shouldReturnUndecided
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionUndecided];

    // -- Assert --
    XCTAssertEqual(header.sampled, SentryObjCSampleDecisionUndecided);
}

- (void)testValue_whenSampledUndecided_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCTraceHeader *header =
        [[SentryObjCTraceHeader alloc] initWithTraceId:traceId
                                                spanId:spanId
                                               sampled:SentryObjCSampleDecisionUndecided];

    // -- Act --
    NSString *value = [header value];

    // -- Assert --
    XCTAssertNotNil(value);
}

@end
