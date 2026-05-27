@import SentryObjC;
@import XCTest;

@interface SentryObjCSpanContextTests : XCTestCase
@end

@implementation SentryObjCSpanContextTests

#pragma mark - initWithOperation

- (void)testInitWithOperation_shouldReturnNonNil
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithOperation_shouldSetOperation
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"http.request");
}

- (void)testInitWithOperation_shouldGenerateTraceId
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertNotNil(ctx.traceId);
}

- (void)testInitWithOperation_shouldGenerateSpanId
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertNotNil(ctx.spanId);
}

- (void)testInitWithOperation_shouldDefaultSampledToUndecided
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionUndecided);
}

- (void)testInitWithOperation_shouldDefaultParentSpanIdToNil
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertNil(ctx.parentSpanId);
}

- (void)testInitWithOperation_shouldDefaultSpanDescriptionToNil
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertNil(ctx.spanDescription);
}

- (void)testInitWithOperation_shouldSetOriginToNonNil
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertNotNil(ctx.origin);
}

#pragma mark - initWithOperation:sampled:

- (void)testInitWithOperationSampled_shouldReturnNonNil
{
    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithOperation:@"db.query"
                                                 sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithOperationSampled_shouldSetOperation
{
    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithOperation:@"db.query"
                                                 sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"db.query");
}

- (void)testInitWithOperationSampled_shouldSetSampled
{
    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithOperation:@"db.query"
                                                 sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionYes);
}

- (void)testInitWithOperationSampled_shouldGenerateTraceId
{
    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithOperation:@"db.query"
                                                 sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertNotNil(ctx.traceId);
}

- (void)testInitWithOperationSampled_shouldGenerateSpanId
{
    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithOperation:@"db.query"
                                                 sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertNotNil(ctx.spanId);
}

#pragma mark - initWithTraceId:spanId:parentId:operation:sampled:

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"ui.load"
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_shouldSetTraceId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"ui.load"
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertEqualObjects(ctx.traceId.sentryIdString, traceId.sentryIdString);
}

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_shouldSetSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"ui.load"
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertEqualObjects(ctx.spanId.sentrySpanIdString, spanId.sentrySpanIdString);
}

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_shouldSetParentSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"ui.load"
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertNotNil(ctx.parentSpanId);
    XCTAssertEqualObjects(ctx.parentSpanId.sentrySpanIdString, parentId.sentrySpanIdString);
}

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_shouldSetOperation
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"ui.load"
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"ui.load");
}

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_shouldSetSampled
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"ui.load"
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionNo);
}

- (void)testInitWithTraceIdSpanIdParentIdOperationSampled_whenNilParent_shouldHaveNilParentSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:nil
                                             operation:@"task"
                                               sampled:SentryObjCSampleDecisionUndecided];

    // -- Assert --
    XCTAssertNotNil(ctx);
    XCTAssertNil(ctx.parentSpanId);
}

#pragma mark - initWithTraceId:spanId:parentId:operation:spanDescription:sampled:

- (void)testInitWithDescription_shouldSetSpanDescription
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"http.client"
                                       spanDescription:@"GET /api/users"
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqualObjects(ctx.spanDescription, @"GET /api/users");
}

- (void)testInitWithDescription_shouldSetOperation
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:parentId
                                             operation:@"http.client"
                                       spanDescription:@"GET /api/users"
                                               sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"http.client");
}

- (void)testInitWithDescription_whenNilDescription_shouldHaveNilSpanDescription
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithTraceId:traceId
                                                spanId:spanId
                                              parentId:nil
                                             operation:@"op"
                                       spanDescription:nil
                                               sampled:SentryObjCSampleDecisionNo];

    // -- Assert --
    XCTAssertNotNil(ctx);
    XCTAssertNil(ctx.spanDescription);
}

#pragma mark - origin

- (void)testOrigin_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"test"];

    // -- Act --
    ctx.origin = @"auto.ui.swift_ui";

    // -- Assert --
    XCTAssertEqualObjects(ctx.origin, @"auto.ui.swift_ui");
}

@end
