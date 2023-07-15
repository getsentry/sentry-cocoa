#import "SentryClient.h"
#import "SentryHub.h"
#import "SentryOptions.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpan.h"
#import "SentryTracer.h"
#import "SentryTransactionContext.h"
#import <XCTest/XCTest.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryProfiler.h"
#    import "SentryProfilesSampler.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@interface SentryTracerObjCTests : XCTestCase

@end

@implementation SentryTracerObjCTests

/**
 * This test makes sure that the span has a weak reference to the tracer and doesn't call the
 * tracer#spanFinished method.
 */
- (void)testSpanFinishesAfterTracerReleased_NoCrash_TracerIsNil
{
    SentrySpan *child;
    // To make sure the tracer is deallocated.
    @autoreleasepool {
        SentryHub *hub = [[SentryHub alloc] initWithClient:nil andScope:nil];
        SentryTransactionContext *context =
            [[SentryTransactionContext alloc] initWithOperation:@""];
        SentryTracer *tracer = [[SentryTracer alloc]
            initWithTransactionContext:context
                                   hub:hub
                         configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                           SentryTracerConfiguration *configuration) {
                             configuration.waitForChildren = YES;
                         }]];

        [tracer finish];
        child = [tracer startChildWithOperation:@"child"];
    }

    XCTAssertNotNil(child);
    [child finish];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)testConcurrentTracerProfiling
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @1;
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    SentryTransactionContext *context1 = [[SentryTransactionContext alloc] initWithName:@"name1"
                                                                              operation:@"op1"];
    SentryTransactionContext *context2 = [[SentryTransactionContext alloc] initWithName:@"name1"
                                                                              operation:@"op2"];
    SentryProfilesSamplerDecision *decision =
        [[SentryProfilesSamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                                  forSampleRate:@1];

    SentryTracer *tracer1 = [[SentryTracer alloc]
        initWithTransactionContext:context1
                               hub:hub
                     configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                       SentryTracerConfiguration *configuration) {
                         configuration.profilesSamplerDecision = decision;
                         configuration.waitForChildren = YES;
                     }]];

    SentryTracer *tracer2 = [[SentryTracer alloc]
        initWithTransactionContext:context2
                               hub:hub
                     configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                       SentryTracerConfiguration *configuration) {
                         configuration.profilesSamplerDecision = decision;
                         configuration.waitForChildren = YES;
                     }]];

    XCTestExpectation *exp = [self expectationWithDescription:@"finishes tracers"];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            XCTAssert([SentryProfiler isCurrentlyProfiling]);

            [tracer1 finish];

            XCTAssert([SentryProfiler isCurrentlyProfiling]);

            [tracer2 finish];

            XCTAssertFalse([SentryProfiler isCurrentlyProfiling]);

            [exp fulfill];
        });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end
