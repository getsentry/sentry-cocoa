#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCSpanContextTests : XCTestCase
@end

@implementation SentryObjCSpanContextTests

#pragma mark - initWithOperation

- (void)testInitWithOperation_shouldSetOperationAndDefaults
{
    // -- Act --
    SentryObjCSpanContext *ctx = [[SentryObjCSpanContext alloc] initWithOperation:@"http.request"];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"http.request");
    XCTAssertGreaterThan(ctx.traceId.sentryIdString.length, 0u);
    XCTAssertGreaterThan(ctx.spanId.sentrySpanIdString.length, 0u);
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionUndecided);
    XCTAssertNil(ctx.parentSpanId);
    XCTAssertNil(ctx.spanDescription);
    XCTAssertGreaterThan(ctx.origin.length, 0u);
}

#pragma mark - initWithOperation:sampled:

- (void)testInitWithOperationSampled_shouldSetBoth
{
    // -- Act --
    SentryObjCSpanContext *ctx =
        [[SentryObjCSpanContext alloc] initWithOperation:@"db.query"
                                                 sampled:SentryObjCSampleDecisionYes];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"db.query");
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionYes);
    XCTAssertGreaterThan(ctx.traceId.sentryIdString.length, 0u);
    XCTAssertGreaterThan(ctx.spanId.sentrySpanIdString.length, 0u);
}

#pragma mark - initWithTraceId:spanId:parentId:operation:sampled:

- (void)testInitWithAllIds_shouldSetAllParameters
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
    XCTAssertEqualObjects(ctx.spanId.sentrySpanIdString, spanId.sentrySpanIdString);
    XCTAssertEqualObjects(ctx.parentSpanId.sentrySpanIdString, parentId.sentrySpanIdString);
    XCTAssertEqualObjects(ctx.operation, @"ui.load");
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionNo);
}

- (void)testInitWithAllIds_whenNilParent_shouldHaveNilParentSpanId
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
    XCTAssertNil(ctx.parentSpanId);
    XCTAssertEqualObjects(ctx.operation, @"task");
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
