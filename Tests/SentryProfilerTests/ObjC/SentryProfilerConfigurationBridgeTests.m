@import XCTest;
#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    import "SentryClient.h"
#    import "SentryDefaultProfilerSDKBackend.h"
#    import "SentryHub+Private.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerConfigurationBridge.h"
#    import "SentryProfilerSDKAdapter.h"
#    if SWIFT_PACKAGE
#        import "SentrySwift.h"
#    else
@import Sentry;
#    endif
#endif

@interface SentryProfilerConfigurationBridgeTests : XCTestCase
#if SENTRY_PROFILER_TESTS_SUPPORTED
@property (nonatomic, strong, nullable) SentryProfileConfiguration *previousConfiguration;
@property (nonatomic) BOOL previouslyTracingLaunch;
#endif
@end

@implementation SentryProfilerConfigurationBridgeTests
#if SENTRY_PROFILER_TESTS_SUPPORTED
- (void)setUp
{
    [super setUp];
    self.previousConfiguration = sentry_getProfileConfiguration();
    self.previouslyTracingLaunch = SentryProfilerSDKAdapter.shared.isTracingAppLaunch;
    sentry_setProfileConfiguration(nil);
    SentryProfilerSDKAdapter.shared.isTracingAppLaunch = NO;
}

- (void)tearDown
{
    sentry_setProfileConfiguration(self.previousConfiguration);
    SentryProfilerSDKAdapter.shared.isTracingAppLaunch = self.previouslyTracingLaunch;
    [super tearDown];
}

- (void)testConfiguration_whenAbsent_shouldDisableLaunchFlags
{
    // -- Arrange --
    SentryDefaultProfilerSDKBackend *backend = [[SentryDefaultProfilerSDKBackend alloc] init];

    // -- Act --
    SentryProfilingConfiguration configuration = [backend configuration];

    // -- Assert --
    XCTAssertFalse(configuration.launchProfileCorrelatedToTraces);
    XCTAssertFalse(configuration.traceLaunchConfigured);
}

- (void)testConfiguration_whenLaunchOptionsChange_shouldReadCurrentValues
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    options.profileAppStarts = YES;
    SentrySamplerDecision *decision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:@0.5
                                         withSampleRand:@0.2];
    sentry_setProfileConfiguration([[SentryProfileConfiguration alloc]
        initContinuousProfilingV2WaitingForFullDisplay:YES
                                       samplerDecision:decision
                                        profileOptions:options]);
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    SentryDefaultProfilerSDKBackend *backend = [[SentryDefaultProfilerSDKBackend alloc] init];
    [adapter setTarget:backend];

    // -- Act & Assert --
    SentryProfilingConfiguration configuration = [adapter configuration];
    XCTAssertTrue(configuration.launchProfileCorrelatedToTraces);
    XCTAssertTrue(configuration.traceLaunchConfigured);
    options.lifecycle = SentryProfileLifecycleManual;
    configuration = [adapter configuration];
    XCTAssertFalse(configuration.launchProfileCorrelatedToTraces);
    XCTAssertFalse(configuration.traceLaunchConfigured);
}

- (void)testConfiguration_whenSDKOptionsRequestLaunchTracing_shouldNotMarkCurrentLaunch
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    options.profileAppStarts = YES;
    sentry_setProfileConfiguration(
        [[SentryProfileConfiguration alloc] initWithProfileOptions:options]);

    // -- Act --
    SentryProfilingConfiguration configuration = sentry_profilerConfigurationSnapshot();

    // -- Assert --
    XCTAssertTrue(configuration.launchProfileCorrelatedToTraces);
    XCTAssertFalse(configuration.traceLaunchConfigured);
}

- (void)testTraceDecision_whenLaunchTraceSampled_shouldSelectContinuousProfiling
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    SentrySamplerDecision *decision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:@0.5
                                         withSampleRand:@0.2];
    sentry_setProfileConfiguration([[SentryProfileConfiguration alloc]
        initContinuousProfilingV2WaitingForFullDisplay:NO
                                       samplerDecision:decision
                                        profileOptions:options]);
    SentryTracerConfiguration *tracer = [[SentryTracerConfiguration alloc] init];
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionYes];

    // -- Act --
    SentryProfilingTraceDecision result = sentry_profilerTraceDecision(tracer, nil, context);

    // -- Assert --
    XCTAssertEqual(result, SentryProfilingTraceDecisionContinuous);
    XCTAssertEqualObjects(decision.sampleRate, @0.5);
    XCTAssertEqualObjects(decision.sampleRand, @0.2);
}

- (void)testTraceDecision_whenSessionNotSampled_shouldNotProfile
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    SentrySamplerDecision *decision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                          forSampleRate:@0.5
                                         withSampleRand:@0.8];
    sentry_setProfileConfiguration([[SentryProfileConfiguration alloc]
        initContinuousProfilingV2WaitingForFullDisplay:NO
                                       samplerDecision:decision
                                        profileOptions:options]);
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionYes];

    // -- Act --
    SentryProfilingTraceDecision result
        = sentry_profilerTraceDecision([[SentryTracerConfiguration alloc] init], nil, context);

    // -- Assert --
    XCTAssertEqual(result, SentryProfilingTraceDecisionNone);
}

- (void)testTraceDecision_whenTraceNotSampled_shouldNotProfile
{
    // -- Arrange --
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    SentrySamplerDecision *decision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:@1
                                         withSampleRand:@0.2];
    sentry_setProfileConfiguration([[SentryProfileConfiguration alloc]
        initContinuousProfilingV2WaitingForFullDisplay:NO
                                       samplerDecision:decision
                                        profileOptions:options]);
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionNo];

    // -- Act --
    SentryProfilingTraceDecision result
        = sentry_profilerTraceDecision([[SentryTracerConfiguration alloc] init], nil, context);

    // -- Assert --
    XCTAssertEqual(result, SentryProfilingTraceDecisionNone);
}

- (void)testTraceDecision_whenPersistedLifecycleManual_shouldTakePrecedenceOverSDKTraceOptions
{
    // -- Arrange --
    SentryProfileOptions *persisted = [[SentryProfileOptions alloc] init];
    SentrySamplerDecision *decision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:@1
                                         withSampleRand:@0.2];
    sentry_setProfileConfiguration([[SentryProfileConfiguration alloc]
        initContinuousProfilingV2WaitingForFullDisplay:NO
                                       samplerDecision:decision
                                        profileOptions:persisted]);
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://public@example.com/1";
    options.profiling = [[SentryProfileOptions alloc] init];
    options.profiling.lifecycle = SentryProfileLifecycleTrace;
    SentryClientInternal *client = [[SentryClientInternal alloc] initWithOptions:options];
    SentryHubInternal *hub = [[SentryHubInternal alloc] initWithClient:client andScope:nil];
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionYes];

    // -- Act --
    SentryProfilingTraceDecision result
        = sentry_profilerTraceDecision([[SentryTracerConfiguration alloc] init], hub, context);

    // -- Assert --
    XCTAssertEqual(result, SentryProfilingTraceDecisionNone);
}

- (void)testTraceDecision_whenTransactionDecisionProvided_shouldHonorFinalSamplingDecision
{
    // -- Arrange --
    SentryTracerConfiguration *tracer = [[SentryTracerConfiguration alloc] init];
    tracer.profilesSamplerDecision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:@0.5
                                         withSampleRand:@0.2];
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionYes];

    // -- Act & Assert --
    XCTAssertEqual(sentry_profilerTraceDecision(tracer, nil, context),
        SentryProfilingTraceDecisionTransaction);
    tracer.profilesSamplerDecision = nil;
    XCTAssertEqual(
        sentry_profilerTraceDecision(tracer, nil, context), SentryProfilingTraceDecisionNone);
}

- (void)testTraceLifecycle_whenClientOptionsChange_shouldReadCurrentValues
{
    // -- Arrange --
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://public@example.com/1";
    options.profiling = [[SentryProfileOptions alloc] init];
    options.profiling.lifecycle = SentryProfileLifecycleTrace;
    SentryClientInternal *client = [[SentryClientInternal alloc] initWithOptions:options];

    // -- Act & Assert --
    XCTAssertTrue(sentry_profilerUsesTraceLifecycle(client));
    options.profiling.lifecycle = SentryProfileLifecycleManual;
    XCTAssertFalse(sentry_profilerUsesTraceLifecycle(client));
    XCTAssertFalse(sentry_profilerUsesTraceLifecycle(nil));
}

- (void)testConfiguration_whenNoBackend_shouldReturnDisabledFlags
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];

    // -- Act --
    SentryProfilingConfiguration configuration = [adapter configuration];
#    if SENTRY_HAS_UIKIT
    [adapter stopFramesTrackerIfUnused];
#    endif

    // -- Assert --
    XCTAssertFalse(configuration.launchProfileCorrelatedToTraces);
    XCTAssertFalse(configuration.traceLaunchConfigured);
}
#endif
@end
