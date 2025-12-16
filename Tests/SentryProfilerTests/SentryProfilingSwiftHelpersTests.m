@import XCTest;
@import Sentry;
@import SentryTestUtilsDynamic;
#import "SentryClient.h"
#import "SentryProfilingSwiftHelpers.h"

@interface SentryProfilingSwiftHelpersTests : XCTestCase
@end

@implementation SentryProfilingSwiftHelpersTests

#if SENTRY_TARGET_PROFILING_SUPPORTED

- (void)testIsContinuousProfilingEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = [[SentryProfileOptions alloc] init];
    SentryClientInternal *client = [[SentryClientInternal alloc] initWithOptions:options];
    XCTAssertEqual(
        [client.options isContinuousProfilingEnabled], sentry_isContinuousProfilingEnabled(client));
}

- (void)testIsProfilingCorrelatedToTraces
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = [[SentryProfileOptions alloc] init];
    options.profiling.lifecycle = SentryProfileLifecycleTrace;
    SentryClientInternal *client = [[SentryClientInternal alloc] initWithOptions:options];
    XCTAssertEqual([client.options isProfilingCorrelatedToTraces],
        sentry_isProfilingCorrelatedToTraces(client));
}

- (void)testGetProfiling
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = [[SentryProfileOptions alloc] init];
    SentryClientInternal *client = [[SentryClientInternal alloc] initWithOptions:options];
    XCTAssertEqual(client.options.profiling, sentry_getProfiling(client));
}

- (void)testGetProfiling_whenProfilingOptionsIsNil_shouldReturnNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = nil;
    SentryClientInternal *client = [[SentryClientInternal alloc] initWithOptions:options];
    XCTAssertNil(sentry_getProfiling(client));
}

- (void)testStringFromSentryID
{
    SentryId *sentryId = [[SentryId alloc] init];
    XCTAssertEqualObjects(sentryId.sentryIdString, sentry_stringFromSentryID(sentryId));
}

- (void)testGetSentryId
{
    XCTAssertNotNil(sentry_getSentryId());
}

- (void)testGetSentryProfileOptions
{
    XCTAssertNotNil(sentry_getSentryProfileOptions());
}

- (void)testIsTraceLifecycle
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    XCTAssertTrue(sentry_isTraceLifecycle(options));

    options.lifecycle = SentryProfileLifecycleManual;
    XCTAssertFalse(sentry_isTraceLifecycle(options));
}

- (void)testSessionSampleRate
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.sessionSampleRate = 0.2;
    XCTAssertEqual(options.sessionSampleRate, sentry_sessionSampleRate(options));
}

- (void)testProfileAppStarts
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.profileAppStarts = true;
    XCTAssertTrue(sentry_profileAppStarts(options));

    options.profileAppStarts = false;
    XCTAssertFalse(sentry_profileAppStarts(options));
}

- (void)testIsManual
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.profileAppStarts = true;
    XCTAssertTrue(sentry_profileAppStarts(options));

    options.profileAppStarts = false;
    XCTAssertFalse(sentry_profileAppStarts(options));
}

- (void)testGetParentSpanID
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertEqual(context.parentSpanId, sentry_getParentSpanID(context));
}

- (void)testGetParentSpanID_whenParentIdIsNil_shouldReturnNil
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertNil(sentry_getParentSpanID(context));
}

- (void)testGetTraceID
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertEqual(context.traceId, sentry_getTraceID(context));
}

- (void)testIsNotSampled
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertTrue(sentry_isNotSampled(context));

    context = [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                         spanId:[[SentrySpanId alloc] init]
                                                       parentId:[[SentrySpanId alloc] init]
                                                      operation:@""
                                                        sampled:kSentrySampleDecisionYes];
    XCTAssertFalse(sentry_isNotSampled(context));
}

#endif

@end
