@import SentryObjC;
@import XCTest;

@interface SentryObjCSamplingContextTests : XCTestCase
@end

@implementation SentryObjCSamplingContextTests

#pragma mark - initWithTransactionContext:

- (void)testInitWithTransactionContext_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCTransactionContext *txCtx =
        [[SentryObjCTransactionContext alloc] initWithName:@"test-tx" operation:@"op"];

    // -- Act --
    SentryObjCSamplingContext *ctx =
        [[SentryObjCSamplingContext alloc] initWithTransactionContext:txCtx];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithTransactionContext_shouldSetTransactionContext
{
    // -- Arrange --
    SentryObjCTransactionContext *txCtx =
        [[SentryObjCTransactionContext alloc] initWithName:@"test-tx" operation:@"op"];

    // -- Act --
    SentryObjCSamplingContext *ctx =
        [[SentryObjCSamplingContext alloc] initWithTransactionContext:txCtx];

    // -- Assert --
    XCTAssertNotNil(ctx.transactionContext);
    XCTAssertEqualObjects(ctx.transactionContext.name, @"test-tx");
}

- (void)testInitWithTransactionContext_shouldDefaultCustomSamplingContextToNil
{
    // -- Arrange --
    SentryObjCTransactionContext *txCtx =
        [[SentryObjCTransactionContext alloc] initWithName:@"test-tx" operation:@"op"];

    // -- Act --
    SentryObjCSamplingContext *ctx =
        [[SentryObjCSamplingContext alloc] initWithTransactionContext:txCtx];

    // -- Assert --
    XCTAssertNil(ctx.customSamplingContext);
}

#pragma mark - initWithTransactionContext:customSamplingContext:

- (void)testInitWithCustomSamplingContext_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCTransactionContext *txCtx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx" operation:@"task"];
    NSDictionary<NSString *, id> *custom = @{ @"user_segment" : @"premium", @"priority" : @1 };

    // -- Act --
    SentryObjCSamplingContext *ctx =
        [[SentryObjCSamplingContext alloc] initWithTransactionContext:txCtx
                                                customSamplingContext:custom];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testInitWithCustomSamplingContext_shouldSetTransactionContext
{
    // -- Arrange --
    SentryObjCTransactionContext *txCtx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx" operation:@"task"];
    NSDictionary<NSString *, id> *custom = @{ @"user_segment" : @"premium", @"priority" : @1 };

    // -- Act --
    SentryObjCSamplingContext *ctx =
        [[SentryObjCSamplingContext alloc] initWithTransactionContext:txCtx
                                                customSamplingContext:custom];

    // -- Assert --
    XCTAssertNotNil(ctx.transactionContext);
    XCTAssertEqualObjects(ctx.transactionContext.name, @"tx");
}

- (void)testInitWithCustomSamplingContext_shouldSetCustomSamplingContext
{
    // -- Arrange --
    SentryObjCTransactionContext *txCtx =
        [[SentryObjCTransactionContext alloc] initWithName:@"tx" operation:@"task"];
    NSDictionary<NSString *, id> *custom = @{ @"user_segment" : @"premium", @"priority" : @1 };

    // -- Act --
    SentryObjCSamplingContext *ctx =
        [[SentryObjCSamplingContext alloc] initWithTransactionContext:txCtx
                                                customSamplingContext:custom];

    // -- Assert --
    XCTAssertNotNil(ctx.customSamplingContext);
    XCTAssertEqualObjects(ctx.customSamplingContext[@"user_segment"], @"premium");
    XCTAssertEqualObjects(ctx.customSamplingContext[@"priority"], @1);
}

@end
