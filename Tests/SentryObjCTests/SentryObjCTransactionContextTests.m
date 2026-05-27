#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCTransactionContextTests : XCTestCase
@end

@implementation SentryObjCTransactionContextTests

#pragma mark - initWithName:operation:

- (void)testInitWithNameOperation_shouldReturnNonNil
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithNameOperation_shouldSetName
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertEqualObjects(ctx.name, @"my-transaction");
}

- (void)testInitWithNameOperation_shouldSetOperation
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"http.request");
}

- (void)testInitWithNameOperation_shouldDefaultNameSourceToCustom
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertEqual(ctx.nameSource, SentryObjCTransactionNameSourceCustom);
}

- (void)testInitWithNameOperation_shouldDefaultSampleRateToNil
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertNil(ctx.sampleRate);
}

- (void)testInitWithNameOperation_shouldDefaultSampleRandToNil
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertNil(ctx.sampleRand);
}

- (void)testInitWithNameOperation_shouldDefaultParentSampleRateToNil
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertNil(ctx.parentSampleRate);
}

- (void)testInitWithNameOperation_shouldDefaultParentSampleRandToNil
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertNil(ctx.parentSampleRand);
}

- (void)testInitWithNameOperation_shouldDefaultForNextAppLaunchToNo
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"my-transaction"
                                                 operation:@"http.request"];

    // -- Assert --
    XCTAssertFalse(ctx.forNextAppLaunch);
}

#pragma mark - initWithName:operation:sampled:sampleRate:sampleRand:

- (void)testInitWithNameOperationSampledSampleRateSampleRand_shouldReturnNonNil
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-sampled"
                                                 operation:@"navigation"
                                                   sampled:SentryObjCSampleDecisionYes
                                                sampleRate:@0.75
                                                sampleRand:@0.5];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithNameOperationSampledSampleRateSampleRand_shouldSetName
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-sampled"
                                                 operation:@"navigation"
                                                   sampled:SentryObjCSampleDecisionYes
                                                sampleRate:@0.75
                                                sampleRand:@0.5];

    // -- Assert --
    XCTAssertEqualObjects(ctx.name, @"tx-sampled");
}

- (void)testInitWithNameOperationSampledSampleRateSampleRand_shouldSetOperation
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-sampled"
                                                 operation:@"navigation"
                                                   sampled:SentryObjCSampleDecisionYes
                                                sampleRate:@0.75
                                                sampleRand:@0.5];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"navigation");
}

- (void)testInitWithNameOperationSampledSampleRateSampleRand_shouldSetSampled
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-sampled"
                                                 operation:@"navigation"
                                                   sampled:SentryObjCSampleDecisionYes
                                                sampleRate:@0.75
                                                sampleRand:@0.5];

    // -- Assert --
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionYes);
}

- (void)testInitWithNameOperationSampledSampleRateSampleRand_shouldSetSampleRate
{
    // -- Arrange --
    NSNumber *rate = @0.75;

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-sampled"
                                                 operation:@"navigation"
                                                   sampled:SentryObjCSampleDecisionYes
                                                sampleRate:rate
                                                sampleRand:@0.5];

    // -- Assert --
    XCTAssertEqualObjects(ctx.sampleRate, rate);
}

- (void)testInitWithNameOperationSampledSampleRateSampleRand_shouldSetSampleRand
{
    // -- Arrange --
    NSNumber *rand = @0.5;

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-sampled"
                                                 operation:@"navigation"
                                                   sampled:SentryObjCSampleDecisionYes
                                                sampleRate:@0.75
                                                sampleRand:rand];

    // -- Assert --
    XCTAssertEqualObjects(ctx.sampleRand, rand);
}

- (void)testInitWithNameOperationSampled_whenNilRates_shouldHaveNilSampleRate
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                 operation:@"op"
                                                   sampled:SentryObjCSampleDecisionNo
                                                sampleRate:nil
                                                sampleRand:nil];

    // -- Assert --
    XCTAssertNil(ctx.sampleRate);
}

- (void)testInitWithNameOperationSampled_whenNilRates_shouldHaveNilSampleRand
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                 operation:@"op"
                                                   sampled:SentryObjCSampleDecisionNo
                                                sampleRate:nil
                                                sampleRand:nil];

    // -- Assert --
    XCTAssertNil(ctx.sampleRand);
}

- (void)testInitWithNameOperationSampled_whenNilRates_shouldSetSampled
{
    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                 operation:@"op"
                                                   sampled:SentryObjCSampleDecisionNo
                                                sampleRate:nil
                                                sampleRand:nil];

    // -- Assert --
    XCTAssertEqual(ctx.sampled, SentryObjCSampleDecisionNo);
}

#pragma mark - initWithName:operation:traceId:spanId:parentSpanId:parentSampled:parentSampleRate:parentSampleRand:

- (void)testInitWithParent_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithParent_shouldSetName
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertEqualObjects(ctx.name, @"tx-parent");
}

- (void)testInitWithParent_shouldSetOperation
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertEqualObjects(ctx.operation, @"task");
}

- (void)testInitWithParent_shouldSetTraceId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertEqualObjects(ctx.traceId.sentryIdString, traceId.sentryIdString);
}

- (void)testInitWithParent_shouldSetSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertEqualObjects(ctx.spanId.sentrySpanIdString, spanId.sentrySpanIdString);
}

- (void)testInitWithParent_shouldSetParentSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertNotNil(ctx.parentSpanId);
}

- (void)testInitWithParent_shouldSetParentSampled
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertEqual(ctx.parentSampled, SentryObjCSampleDecisionYes);
}

- (void)testInitWithParent_shouldSetParentSampleRate
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];
    NSNumber *parentRate = @0.5;

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:parentRate
                                          parentSampleRand:@0.3];

    // -- Assert --
    XCTAssertEqualObjects(ctx.parentSampleRate, parentRate);
}

- (void)testInitWithParent_shouldSetParentSampleRand
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *parentSpanId = [[SentryObjCSpanId alloc] init];
    NSNumber *parentRand = @0.3;

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx-parent"
                                                 operation:@"task"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:parentSpanId
                                             parentSampled:SentryObjCSampleDecisionYes
                                          parentSampleRate:@0.5
                                          parentSampleRand:parentRand];

    // -- Assert --
    XCTAssertEqualObjects(ctx.parentSampleRand, parentRand);
}

- (void)testInitWithParent_whenNilParentSpanId_shouldHaveNilParentSpanId
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                 operation:@"op"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:nil
                                             parentSampled:SentryObjCSampleDecisionUndecided
                                          parentSampleRate:nil
                                          parentSampleRand:nil];

    // -- Assert --
    XCTAssertNil(ctx.parentSpanId);
}

- (void)testInitWithParent_whenNilRates_shouldHaveNilParentSampleRate
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                 operation:@"op"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:nil
                                             parentSampled:SentryObjCSampleDecisionUndecided
                                          parentSampleRate:nil
                                          parentSampleRand:nil];

    // -- Assert --
    XCTAssertNil(ctx.parentSampleRate);
}

- (void)testInitWithParent_whenNilRates_shouldHaveNilParentSampleRand
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    SentryObjCTransactionContext *ctx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                 operation:@"op"
                                                   traceId:traceId
                                                    spanId:spanId
                                              parentSpanId:nil
                                             parentSampled:SentryObjCSampleDecisionUndecided
                                          parentSampleRate:nil
                                          parentSampleRand:nil];

    // -- Assert --
    XCTAssertNil(ctx.parentSampleRand);
}

#pragma mark - Read-write properties

- (void)testSampleRate_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.sampleRate = @0.9;

    // -- Assert --
    XCTAssertEqualObjects(ctx.sampleRate, @0.9);
}

- (void)testSampleRand_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.sampleRand = @0.42;

    // -- Assert --
    XCTAssertEqualObjects(ctx.sampleRand, @0.42);
}

- (void)testParentSampled_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.parentSampled = SentryObjCSampleDecisionNo;

    // -- Assert --
    XCTAssertEqual(ctx.parentSampled, SentryObjCSampleDecisionNo);
}

- (void)testParentSampleRate_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.parentSampleRate = @0.1;

    // -- Assert --
    XCTAssertEqualObjects(ctx.parentSampleRate, @0.1);
}

- (void)testParentSampleRand_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.parentSampleRand = @0.05;

    // -- Assert --
    XCTAssertEqualObjects(ctx.parentSampleRand, @0.05);
}

- (void)testForNextAppLaunch_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.forNextAppLaunch = YES;

    // -- Assert --
    XCTAssertTrue(ctx.forNextAppLaunch);
}

#pragma mark - Inherited SpanContext properties

- (void)testTraceId_whenCreated_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    SentryObjCId *traceId = ctx.traceId;

    // -- Assert --
    XCTAssertNotNil(traceId);
}

- (void)testSpanId_whenCreated_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    SentryObjCSpanId *spanId = ctx.spanId;

    // -- Assert --
    XCTAssertNotNil(spanId);
}

- (void)testOrigin_whenCreated_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    NSString *origin = ctx.origin;

    // -- Assert --
    XCTAssertNotNil(origin);
}

- (void)testOrigin_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"tx"
                                                                                 operation:@"op"];

    // -- Act --
    ctx.origin = @"auto.app.start";

    // -- Assert --
    XCTAssertEqualObjects(ctx.origin, @"auto.app.start");
}

@end
