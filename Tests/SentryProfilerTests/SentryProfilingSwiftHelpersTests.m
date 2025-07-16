@import XCTest;
@import Sentry;
@import SentryTestUtilsDynamic;
#import "SentryOptions+Private.h"
#import "SentryProfilingSwiftHelpers.h"

@interface SentryProfilingSwiftHelpersTests : XCTestCase
@end

@implementation SentryProfilingSwiftHelpersTests

#if SENTRY_TARGET_PROFILING_SUPPORTED

- (void)testIsContinuousProfilingEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    XCTAssertEqual(
        [client.options isContinuousProfilingEnabled], isContinuousProfilingEnabled(client));
}

- (void)testIsContinuousProfilingV2Enabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = [[SentryProfileOptions alloc] init];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    XCTAssertEqual(
        [client.options isContinuousProfilingV2Enabled], isContinuousProfilingV2Enabled(client));
}

- (void)testIsProfilingCorrelatedToTraces
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = [[SentryProfileOptions alloc] init];
    options.profiling.lifecycle = SentryProfileLifecycleTrace;
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    XCTAssertEqual(
        [client.options isProfilingCorrelatedToTraces], isProfilingCorrelatedToTraces(client));
}

- (void)testGetProfiling
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://username:password@app.getsentry.com/12345";
    options.profiling = [[SentryProfileOptions alloc] init];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    XCTAssertEqual(client.options.profiling, getProfiling(client));
}

- (void)testStringFromSentryID
{
    SentryId *sentryId = [[SentryId alloc] init];
    XCTAssertEqualObjects(sentryId.sentryIdString, stringFromSentryID(sentryId));
}

- (void)testGetSentryId
{
    XCTAssertNotNil(getSentryId());
}

- (void)testGetSentryProfileOptions
{
    XCTAssertNotNil(getSentryProfileOptions());
}

- (void)testIsTraceLifecycle
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    XCTAssertTrue(isTraceLifecycle(options));

    options.lifecycle = SentryProfileLifecycleManual;
    XCTAssertFalse(isTraceLifecycle(options));
}

- (void)testSessionSampleRate
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.sessionSampleRate = 0.2;
    XCTAssertEqual(options.sessionSampleRate, sessionSampleRate(options));
}

- (void)testProfileAppStarts
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.profileAppStarts = true;
    XCTAssertTrue(profileAppStarts(options));

    options.profileAppStarts = false;
    XCTAssertFalse(profileAppStarts(options));
}

- (void)testIsManual
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.profileAppStarts = true;
    XCTAssertTrue(profileAppStarts(options));

    options.profileAppStarts = false;
    XCTAssertFalse(profileAppStarts(options));
}

- (void)testGetParentSpanID
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertEqual(context.parentSpanId, getParentSpanID(context));
}

- (void)testGetTraceID
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertEqual(context.traceId, getTraceID(context));
}

- (void)testIsNotSampled
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertTrue(isNotSampled(context));

    context = [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                         spanId:[[SentrySpanId alloc] init]
                                                       parentId:[[SentrySpanId alloc] init]
                                                      operation:@""
                                                        sampled:kSentrySampleDecisionYes];
    XCTAssertFalse(isNotSampled(context));
}

#endif

@end
