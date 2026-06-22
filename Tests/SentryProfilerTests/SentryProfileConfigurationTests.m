@import XCTest;
@import Sentry;
#import "SentryProfileConfiguration.h"
#import "SentryProfiler+Private.h"

@interface SentryProfileConfigurationTests : XCTestCase
@end

@implementation SentryProfileConfigurationTests

#if SENTRY_TARGET_PROFILING_SUPPORTED

- (void)tearDown
{
    sentry_setProfileConfiguration(nil);
    [super tearDown];
}

- (void)testReevaluateSessionSampleRate_whenReadingSampleDecisionConcurrently_shouldNotCrash
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.sessionSampleRate = 1;
    SentryProfileConfiguration *configuration =
        [[SentryProfileConfiguration alloc] initWithProfileOptions:options];
    [configuration reevaluateSessionSampleRate];

    NSUInteger taskCount = 20;
    NSUInteger loopCount = 1000;
    XCTestExpectation *expectation =
        [self expectationWithDescription:@"Concurrent profile configuration access"];
    expectation.expectedFulfillmentCount = taskCount * 2;
    expectation.assertForOverFulfill = YES;
    dispatch_queue_attr_t attributes
        = dispatch_queue_attr_make_initially_inactive(DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queue
        = dispatch_queue_create("io.sentry.profile-configuration-test", attributes);

    // -- Act --
    for (NSUInteger i = 0; i < taskCount; i++) {
        dispatch_async(queue, ^{
            for (NSUInteger j = 0; j < loopCount; j++) {
                [configuration reevaluateSessionSampleRate];
            }
            [expectation fulfill];
        });
        dispatch_async(queue, ^{
            for (NSUInteger j = 0; j < loopCount; j++) {
                SentrySamplerDecision *decision = configuration.profilerSessionSampleDecision;
                (void)decision.decision;
            }
            [expectation fulfill];
        });
    }

    dispatch_activate(queue);
    [self waitForExpectations:@[ expectation ] timeout:5.0];

    // -- Assert --
    XCTAssertNotNil(configuration.profilerSessionSampleDecision);
}

- (void)testReevaluateSessionSampleRate_whenProfileConfigurationChangesConcurrently_shouldNotCrash
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.sessionSampleRate = 1;

    NSUInteger taskCount = 20;
    NSUInteger loopCount = 1000;
    dispatch_queue_attr_t attributes
        = dispatch_queue_attr_make_initially_inactive(DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queue
        = dispatch_queue_create("io.sentry.global-profile-configuration-test", attributes);
    dispatch_group_t group = dispatch_group_create();

    // -- Act --
    for (NSUInteger i = 0; i < taskCount; i++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger j = 0; j < loopCount; j++) {
                SentryProfileConfiguration *configuration =
                    [[SentryProfileConfiguration alloc] initWithProfileOptions:options];
                sentry_setProfileConfiguration(configuration);
                sentry_setProfileConfiguration(nil);
            }
        });
        dispatch_group_async(group, queue, ^{
            for (NSUInteger j = 0; j < loopCount; j++) {
                sentry_reevaluateSessionSampleRate();
            }
        });
    }

    dispatch_activate(queue);

    // -- Assert --
    long waitResult
        = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    XCTAssertEqual(waitResult, 0L);
    SentryProfileConfiguration *configuration =
        [[SentryProfileConfiguration alloc] initWithProfileOptions:options];
    sentry_setProfileConfiguration(configuration);
    sentry_reevaluateSessionSampleRate();
    SentryProfileConfiguration *storedConfiguration = sentry_getProfileConfiguration();
    XCTAssertNotNil(storedConfiguration.profilerSessionSampleDecision);
}

#endif

@end
