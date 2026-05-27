#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCTraceContextTests : XCTestCase
@end

@implementation SentryObjCTraceContextTests

- (void)testInitWithTestDict_shouldSetAllProperties
{
    // -- Arrange --
    NSDictionary *dict = @{
        @"trace_id" : @"a0a0a0a0b1b1b1b1c2c2c2c2d3d3d3d3",
        @"public_key" : @"abc123publickey",
        @"release" : @"com.example.app@1.0.0",
        @"environment" : @"production",
        @"transaction" : @"/api/users",
        @"sample_rate" : @"0.5",
        @"sample_rand" : @"0.123456",
        @"sampled" : @"true",
        @"replay_id" : @"e4e4e4e4f5f5f5f5a6a6a6a6b7b7b7b7",
        @"org_id" : @"42"
    };

    // -- Act --
    SentryObjCTraceContext *ctx = [[SentryObjCTraceContext alloc] initWithTestDict:dict];

    // -- Assert --
    XCTAssertNotNil(ctx);
    XCTAssertEqualObjects(ctx.traceId.sentryIdString, @"a0a0a0a0b1b1b1b1c2c2c2c2d3d3d3d3");
    XCTAssertEqualObjects(ctx.publicKey, @"abc123publickey");
    XCTAssertEqualObjects(ctx.releaseName, @"com.example.app@1.0.0");
    XCTAssertEqualObjects(ctx.environment, @"production");
    XCTAssertEqualObjects(ctx.transaction, @"/api/users");
    XCTAssertEqualObjects(ctx.sampleRate, @"0.5");
    XCTAssertEqualObjects(ctx.sampleRand, @"0.123456");
    XCTAssertEqualObjects(ctx.sampled, @"true");
    XCTAssertEqualObjects(ctx.replayId, @"e4e4e4e4f5f5f5f5a6a6a6a6b7b7b7b7");
    XCTAssertEqualObjects(ctx.orgId, @"42");
}

- (void)testInitWithTestDict_whenOptionalFieldsMissing_shouldReturnNilForOptionals
{
    // -- Arrange --
    NSDictionary *dict =
        @{ @"trace_id" : @"a0a0a0a0b1b1b1b1c2c2c2c2d3d3d3d3", @"public_key" : @"abc123publickey" };

    // -- Act --
    SentryObjCTraceContext *ctx = [[SentryObjCTraceContext alloc] initWithTestDict:dict];

    // -- Assert --
    XCTAssertNotNil(ctx);
    XCTAssertEqualObjects(ctx.traceId.sentryIdString, @"a0a0a0a0b1b1b1b1c2c2c2c2d3d3d3d3");
    XCTAssertEqualObjects(ctx.publicKey, @"abc123publickey");
    XCTAssertNil(ctx.releaseName);
    XCTAssertNil(ctx.environment);
    XCTAssertNil(ctx.transaction);
    XCTAssertNil(ctx.sampleRate);
    XCTAssertNil(ctx.sampleRand);
    XCTAssertNil(ctx.sampled);
    XCTAssertNil(ctx.replayId);
    XCTAssertNil(ctx.orgId);
}

- (void)testInitWithTestDict_whenMissingRequiredKeys_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dict = @{ @"environment" : @"staging" };

    // -- Act --
    SentryObjCTraceContext *ctx = [[SentryObjCTraceContext alloc] initWithTestDict:dict];

    // -- Assert --
    XCTAssertNil(ctx);
}

@end
