@import XCTest;
#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    import "SentryContinuousProfiler+Test.h"
#    import "SentryDefaultProfilerSDKBackend.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerCancellation.h"
#    import "SentryProfilerDeliveryBridge.h"
#    import "SentryProfilerDeliveryTestHub.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilerState.h"
#    import "SentrySDK+Private.h"
#    import "SentrySDKInternal+Tests.h"
#    import "SentryTraceProfiler+Test.h"
#    import "SentryTracer+Private.h"
#    if SWIFT_PACKAGE
#        import "SentrySwift.h"
#    else
@import Sentry;
#    endif
#endif

#if SENTRY_PROFILER_TESTS_SUPPORTED
@interface TestProfilerDeliveryBackend : SentryDefaultProfilerSDKBackend
@property (nonatomic, copy, nullable) dispatch_block_t pendingBlock;
@property (nonatomic, copy, nullable) dispatch_block_t pendingTimerBlock;
@end

@implementation TestProfilerDeliveryBackend
- (void)dispatchAsync:(dispatch_block_t)block
{
    self.pendingBlock = block;
}

- (uint64_t)systemTime
{
    return 1000;
}

- (id<SentryProfilingCancellation>)scheduleTimerWithInterval:(NSTimeInterval)interval
                                                     repeats:(BOOL)repeats
                                                       block:(dispatch_block_t)block
{
    self.pendingTimerBlock = block;
    __weak TestProfilerDeliveryBackend *weakSelf = self;
    return [[SentryProfilerCancellation alloc]
        initWithCancellation:^{ weakSelf.pendingTimerBlock = nil; }];
}
@end
#endif

@interface SentryProfilerDeliveryBridgeTests : XCTestCase
#if SENTRY_PROFILER_TESTS_SUPPORTED
@property (nonatomic, strong, nullable) SentryHubInternal *previousHub;
@property (nonatomic, strong, nullable) SentryProfileConfiguration *previousConfiguration;
@property (nonatomic) BOOL previouslyTracingLaunch;
@property (nonatomic, strong) id<SentryProfilerSDKBackend> previousBackend;
@property (nonatomic, strong) TestProfilerDeliveryBackend *backend;
@property (nonatomic, strong, nullable) SentryProfiler *traceProfiler;
@property (nonatomic) BOOL usesContinuousProfiler;
#    if SENTRY_HAS_UIKIT
@property (nonatomic) BOOL framesTrackerWasRunning;
#    endif
#endif
@end

@implementation SentryProfilerDeliveryBridgeTests
#if SENTRY_PROFILER_TESTS_SUPPORTED
- (void)setUp
{
    [super setUp];
    (void)SentryDependencyContainer.sharedInstance;
    self.previousBackend = SentryProfilerSDKAdapter.shared.target;
    self.backend = [[TestProfilerDeliveryBackend alloc] init];
    [SentryProfilerSDKAdapter.shared setTarget:self.backend];
    self.previousHub = SentrySDKInternal.currentHub;
    self.previousConfiguration = sentry_getProfileConfiguration();
    self.previouslyTracingLaunch = SentryProfilerSDKAdapter.shared.isTracingAppLaunch;
#    if SENTRY_HAS_UIKIT
    self.framesTrackerWasRunning = SentryDependencyContainer.sharedInstance.framesTracker.isRunning;
#    endif
    sentry_setProfileConfiguration(nil);
    SentryProfilerSDKAdapter.shared.isTracingAppLaunch = NO;
}

- (void)tearDown
{
    [self.traceProfiler stopForReason:SentryProfilerTruncationReasonNormal];
    if (self.usesContinuousProfiler) {
        [SentryContinuousProfiler stopTimerAndCleanup];
    }
    [_sentry_threadUnsafe_traceProfileTimeoutTimer cancel];
    _sentry_threadUnsafe_traceProfileTimeoutTimer = nil;
    sentry_resetConcurrencyTracking();
    self.backend.pendingBlock = nil;
    self.backend.pendingTimerBlock = nil;
#    if SENTRY_HAS_UIKIT
    if (!self.framesTrackerWasRunning) {
        [SentryDependencyContainer.sharedInstance.framesTracker stop];
    }
#    endif
    [SentryProfilerSDKAdapter.shared setTarget:self.previousBackend];
    [SentrySDKInternal setCurrentHub:self.previousHub];
    sentry_setProfileConfiguration(self.previousConfiguration);
    SentryProfilerSDKAdapter.shared.isTracingAppLaunch = self.previouslyTracingLaunch;
    [super tearDown];
}

- (void)testFinishTransaction_whenNotProfiled_shouldCaptureOnSelectedHubWithoutDispatch
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *selected =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil andScope:nil];
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionYes];
    SentryTracer *tracer =
        [[SentryTracer alloc] initWithTransactionContext:context
                                                     hub:selected
                                           configuration:[[SentryTracerConfiguration alloc] init]];
    [tracer finish];
    SentryTransaction *transaction = selected.lastTransaction;
    XCTAssertNotNil(transaction);
    selected.transactionCount = 0;
    selected.lastTransaction = nil;
    SentryProfilerDeliveryTestHub *current =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil andScope:nil];
    [SentrySDKInternal setCurrentHub:current];

    // -- Act --
    sentry_finishProfiledTransaction(
        selected,
        ^(__unused dispatch_block_t block) {
            XCTFail(@"Unprofiled transactions must not queue profile serialization");
        },
        transaction, NO, NO, NO, tracer.startTimestamp, 0
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );

    // -- Assert --
    XCTAssertEqual(selected.transactionCount, 1U);
    XCTAssertEqual(selected.lastTransaction, transaction);
    XCTAssertEqual(selected.lastScope, selected.scope);
    XCTAssertEqual(current.transactionCount, 0U);
}

- (void)testFinishTransaction_whenContinuousRootsFinish_shouldStopOnlyAfterLastRoot
{
    // -- Arrange --
    [self configureContinuousProfilingForLaunch:NO];
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil
                                                                                      andScope:nil];
    SentryTransaction *first = [self profiledTransactionOnHub:hub];
    SentryTransaction *second = [self profiledTransactionOnHub:hub];
    dispatch_block_t timerElapsed = self.backend.pendingTimerBlock;
    XCTAssertNotNil(timerElapsed);
    XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling);

    // -- Act --
    sentry_finishProfiledTransaction(
        hub,
        ^(__unused dispatch_block_t block) {
            XCTFail(@"Continuous traces must not queue transaction profile serialization");
        },
        first, YES, NO, YES, first.startTimestamp, 100
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );
    if (timerElapsed != nil) {
        timerElapsed();
    }

    // -- Assert --
    XCTAssertEqual(hub.transactionCount, 1U);
    XCTAssertEqual(hub.lastTransaction, first);
    XCTAssertEqual(hub.lastScope, hub.scope);
    XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling);

    // -- Act --
    sentry_finishProfiledTransaction(
        hub,
        ^(__unused dispatch_block_t block) {
            XCTFail(@"Continuous traces must not queue transaction profile serialization");
        },
        second, YES, NO, YES, second.startTimestamp, 100
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );
    if (timerElapsed != nil) {
        timerElapsed();
    }

    // -- Assert --
    XCTAssertEqual(hub.transactionCount, 2U);
    XCTAssertEqual(hub.lastTransaction, second);
    XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling);
}

- (void)testFinishTransaction_whenLaunchTraceFinishes_shouldDiscardOnlyLaunchTransaction
{
    // -- Arrange --
    [self configureContinuousProfilingForLaunch:YES];
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil
                                                                                      andScope:nil];
    SentryTransaction *launch = [self profiledTransactionOnHub:hub];
    SentryTransaction *other = [self profiledTransactionOnHub:hub];
    dispatch_block_t timerElapsed = self.backend.pendingTimerBlock;
    XCTAssertNotNil(timerElapsed);

    // -- Act --
    sentry_finishProfiledTransaction(
        hub,
        ^(__unused dispatch_block_t block) {
            XCTFail(@"Launch traces must not queue transaction profile serialization");
        },
        launch, YES, YES, YES, launch.startTimestamp, 100
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );
    if (timerElapsed != nil) {
        timerElapsed();
    }

    // -- Assert --
    XCTAssertEqual(hub.transactionCount, 0U);
    XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling);

    // -- Act --
    sentry_finishProfiledTransaction(
        hub,
        ^(__unused dispatch_block_t block) {
            XCTFail(@"Continuous traces must not queue transaction profile serialization");
        },
        other, YES, NO, YES, other.startTimestamp, 100
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );
    if (timerElapsed != nil) {
        timerElapsed();
    }

    // -- Assert --
    XCTAssertEqual(hub.transactionCount, 1U);
    XCTAssertEqual(hub.lastTransaction, other);
    XCTAssertEqual(hub.lastScope, hub.scope);
    XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling);
}

- (void)testFinishTransaction_whenProfiled_shouldQueueProfileOnSelectedHub
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *selected =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil andScope:nil];
    SentryTransaction *transaction = [self profiledTransactionOnHub:selected];
    [self populateTraceProfileState];
    SentryProfilerDeliveryTestHub *current =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil andScope:nil];
    [SentrySDKInternal setCurrentHub:current];
    __block dispatch_block_t pendingSerialization;
    __block NSUInteger dispatches = 0;
    NSDate *startTimestamp = [NSDate dateWithTimeIntervalSince1970:123];

    // -- Act --
    sentry_finishProfiledTransaction(
        selected,
        ^(dispatch_block_t block) {
            dispatches++;
            pendingSerialization = block;
        },
        transaction, YES, NO, NO, startTimestamp, 100
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );

    // -- Assert --
    XCTAssertEqual(dispatches, 1U);
    XCTAssertNotNil(pendingSerialization);
    XCTAssertEqual(selected.transactionCount, 0U);
    XCTAssertEqual(current.transactionCount, 0U);
    XCTAssertEqual(transaction.startSystemTime, 100ULL);
    XCTAssertEqual(transaction.endSystemTime, 1000ULL);
    XCTAssertEqual(sentry_currentProfiledTracers(), 0U);

    // -- Act --
    if (pendingSerialization != nil) {
        pendingSerialization();
    }

    // -- Assert --
    XCTAssertEqual(selected.transactionCount, 1U);
    XCTAssertEqual(selected.lastTransaction, transaction);
    XCTAssertEqual(selected.lastScope, selected.scope);
    XCTAssertEqual(current.transactionCount, 0U);
    XCTAssertEqual(selected.lastAdditionalEnvelopeItems.count, 1U);
    SentryEnvelopeItem *item = selected.lastAdditionalEnvelopeItems.firstObject;
    XCTAssertNotNil(item);
    if (item == nil) {
        return;
    }
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:transaction.eventId
                                                       singleItem:item];
    NSData *wire = [SentrySerializationSwift dataWithEnvelope:envelope];
    NSString *wireString = [[NSString alloc] initWithData:wire encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [wireString componentsSeparatedByString:@"\n"];
    XCTAssertGreaterThanOrEqual(lines.count, 2U);
    if (lines.count < 2) {
        return;
    }
    NSError *error = nil;
    NSDictionary *itemHeader =
        [NSJSONSerialization JSONObjectWithData:[lines[1] dataUsingEncoding:NSUTF8StringEncoding]
                                        options:0
                                          error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(itemHeader[@"type"], @"profile");
    NSDictionary *payload = item.data == nil
        ? nil
        : [NSJSONSerialization JSONObjectWithData:item.data options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(payload[@"version"], @"1");
    XCTAssertEqual([payload[@"profile"][@"samples"] count], 2U);
    XCTAssertEqualObjects(payload[@"transaction"][@"id"], transaction.eventId.sentryIdString);
    XCTAssertEqualObjects(payload[@"timestamp"], @"1970-01-01T00:02:03.000Z");
}

- (void)testFinishTransaction_whenProfileSerializationFails_shouldCaptureWithoutProfile
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil
                                                                                      andScope:nil];
    SentryTransaction *transaction = [self profiledTransactionOnHub:hub];
    self.traceProfiler.state = [[SentryProfilerState alloc] init];
    __block dispatch_block_t pendingSerialization;

    // -- Act --
    sentry_finishProfiledTransaction(
        hub, ^(dispatch_block_t block) { pendingSerialization = block; }, transaction, YES, NO, NO,
        transaction.startTimestamp, 100
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );

    // -- Assert --
    XCTAssertNotNil(pendingSerialization);
    XCTAssertEqual(hub.transactionCount, 0U);

    // -- Act --
    if (pendingSerialization != nil) {
        pendingSerialization();
    }

    // -- Assert --
    XCTAssertEqual(hub.transactionCount, 1U);
    XCTAssertEqual(hub.lastTransaction, transaction);
    XCTAssertEqual(hub.lastScope, hub.scope);
    XCTAssertEqual(hub.lastAdditionalEnvelopeItems.count, 0U);
    XCTAssertEqual(sentry_currentProfiledTracers(), 0U);
}

- (void)testCaptureChunk_whenHubReplacedBeforeDispatch_shouldCaptureOnlyOnOriginatingHub
{
    // -- Arrange --
    SentryClientInternal *client =
        [[SentryClientInternal alloc] initWithOptions:[[SentryOptions alloc] init]];
    SentryProfilerDeliveryTestHub *origin =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:client andScope:nil];
    [origin.scope setEnvironment:@"origin-environment"];
    [SentrySDKInternal setCurrentHub:origin];
    TestProfilerDeliveryBackend *backend = [[TestProfilerDeliveryBackend alloc] init];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];
    [backend captureProfileChunkWithID:@"0123456789abcdef0123456789abcdef"
                                  data:state
                               metrics:^{ return @ { }; }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];
    SentryProfilerDeliveryTestHub *replacement =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:client andScope:nil];
    [replacement.scope setEnvironment:@"replacement-environment"];
    [SentrySDKInternal setCurrentHub:replacement];
    XCTAssertNotNil(backend.pendingBlock);
    XCTAssertEqual(origin.envelopeCount, 0U);

    // -- Act --
    if (backend.pendingBlock != nil) {
        backend.pendingBlock();
    }

    // -- Assert --
    XCTAssertEqual(origin.envelopeCount, 1U);
    XCTAssertEqual(replacement.envelopeCount, 0U);
    NSError *error = nil;
    NSData *data = origin.lastEnvelope.items.firstObject.data;
    NSDictionary *payload
        = data == nil ? nil : [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(payload[@"environment"], @"origin-environment");
}

- (void)testCaptureChunk_whenOriginatingHubClosesBeforeDispatch_shouldDropPendingChunk
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *origin = [[SentryProfilerDeliveryTestHub alloc]
        initWithClient:[[SentryClientInternal alloc] initWithOptions:[[SentryOptions alloc] init]]
              andScope:nil];
    [SentrySDKInternal setCurrentHub:origin];
    TestProfilerDeliveryBackend *backend = [[TestProfilerDeliveryBackend alloc] init];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];
    [backend captureProfileChunkWithID:@"0123456789abcdef0123456789abcdef"
                                  data:state
                               metrics:^{ return @ { }; }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];
    [origin close];
    [origin bindClient:nil];
    SentryProfilerDeliveryTestHub *replacement = [[SentryProfilerDeliveryTestHub alloc]
        initWithClient:[[SentryClientInternal alloc] initWithOptions:[[SentryOptions alloc] init]]
              andScope:nil];
    [SentrySDKInternal setCurrentHub:replacement];
    XCTAssertNotNil(backend.pendingBlock);

    // -- Act --
    if (backend.pendingBlock != nil) {
        backend.pendingBlock();
    }

    // -- Assert --
    XCTAssertNil(origin.getClient);
    XCTAssertNotNil(replacement.getClient);
    XCTAssertEqual(origin.envelopeCount, 0U);
    XCTAssertEqual(replacement.envelopeCount, 0U);
}

- (void)testCaptureChunk_whenMetricsProvided_shouldSerializeOnlyDuringDispatch
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc]
        initWithClient:[[SentryClientInternal alloc] initWithOptions:[[SentryOptions alloc] init]]
              andScope:nil];
    [SentrySDKInternal setCurrentHub:hub];
    TestProfilerDeliveryBackend *backend = [[TestProfilerDeliveryBackend alloc] init];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];
    __block NSUInteger serializations = 0;

    // -- Act --
    [backend captureProfileChunkWithID:@"0123456789abcdef0123456789abcdef"
                                  data:state
                               metrics:^{
                                   serializations++;
                                   return @ { };
                               }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

    // -- Assert --
    XCTAssertEqual(serializations, 0U);
    XCTAssertEqual(hub.envelopeCount, 0U);
    XCTAssertNotNil(backend.pendingBlock);

    // -- Act --
    if (backend.pendingBlock != nil) {
        backend.pendingBlock();
    }

    // -- Assert --
    XCTAssertEqual(serializations, 1U);
    XCTAssertEqual(hub.envelopeCount, 1U);
}

- (void)testCaptureChunk_whenSnapshotProvided_shouldPreservePayloadAndEnvelopeIdentity
{
    // -- Arrange --
    SentryClientInternal *client =
        [[SentryClientInternal alloc] initWithOptions:[[SentryOptions alloc] init]];
    SentryProfilerDeliveryTestHub *hub =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:client andScope:nil];
    [hub.scope setEnvironment:@"delivery-scope"];
    [SentrySDKInternal setCurrentHub:hub];
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    TestProfilerDeliveryBackend *backend = [[TestProfilerDeliveryBackend alloc] init];
    [adapter setTarget:backend];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];
    NSDictionary *metrics = @{
        @"cpu_usage" :
            @ { @"unit" : @"percent", @"values" : @[ @{ @"timestamp" : @123, @"value" : @25 } ] }
    };
    NSString *profileID = @"0123456789abcdef0123456789abcdef";

    // -- Act --
    [adapter captureProfileChunkWithID:profileID
                                  data:state
                               metrics:^{ return metrics; }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

    XCTAssertNotNil(backend.pendingBlock);
    backend.pendingBlock();

    // -- Assert --
    XCTAssertEqual(hub.envelopeCount, 1U);
    SentryEnvelope *envelope = hub.lastEnvelope;
    XCTAssertEqual(envelope.items.count, 1U);
    SentryEnvelopeItem *item = envelope.items.firstObject;
    NSData *wire = [SentrySerializationSwift dataWithEnvelope:envelope];
    NSString *wireString = [[NSString alloc] initWithData:wire encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [wireString componentsSeparatedByString:@"\n"];
    XCTAssertGreaterThanOrEqual(lines.count, 2U);
    if (lines.count < 2) {
        return;
    }
    NSError *error = nil;
    NSDictionary *itemHeader =
        [NSJSONSerialization JSONObjectWithData:[lines[1] dataUsingEncoding:NSUTF8StringEncoding]
                                        options:0
                                          error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(itemHeader[@"type"], @"profile_chunk");
    XCTAssertEqualObjects(itemHeader[@"platform"], @"cocoa");
    NSData *data = item.data;
    XCTAssertNotNil(data);
    if (data == nil) {
        return;
    }
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(payload[@"version"], @"2");
    XCTAssertEqualObjects(payload[@"profiler_id"], profileID);
    XCTAssertEqualObjects(payload[@"chunk_id"], envelope.header.eventId.sentryIdString);
    XCTAssertEqualObjects(payload[@"environment"], @"delivery-scope");
    XCTAssertEqualObjects(payload[@"measurements"], metrics);
}

- (void)testCaptureChunk_whenMetricsCannotBeEncoded_shouldNotCaptureEnvelope
{
    // -- Arrange --
    SentryClientInternal *client =
        [[SentryClientInternal alloc] initWithOptions:[[SentryOptions alloc] init]];
    SentryProfilerDeliveryTestHub *hub =
        [[SentryProfilerDeliveryTestHub alloc] initWithClient:client andScope:nil];
    [SentrySDKInternal setCurrentHub:hub];
    TestProfilerDeliveryBackend *backend = [[TestProfilerDeliveryBackend alloc] init];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];

    // -- Act --
    [backend captureProfileChunkWithID:@"0123456789abcdef0123456789abcdef"
                                  data:state
                               metrics:^{ return @ { @"unsupported" : [NSDate date] }; }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

    XCTAssertNotNil(backend.pendingBlock);
    backend.pendingBlock();

    // -- Assert --
    XCTAssertEqual(hub.envelopeCount, 0U);
}

- (void)testCaptureChunk_whenNoBackend_shouldNotCaptureEnvelope
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil
                                                                                      andScope:nil];
    [SentrySDKInternal setCurrentHub:hub];
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];

    // -- Act --
    [adapter captureProfileChunkWithID:@"0123456789abcdef0123456789abcdef"
                                  data:state
                               metrics:^{ return @ { }; }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

    // -- Assert --
    XCTAssertEqual(hub.envelopeCount, 0U);
}

- (void)configureContinuousProfilingForLaunch:(BOOL)isLaunch
{
    SentryProfileOptions *options = [[SentryProfileOptions alloc] init];
    options.lifecycle = SentryProfileLifecycleTrace;
    options.profileAppStarts = isLaunch;
    options.sessionSampleRate = 1;
    SentryProfileConfiguration *configuration;
    if (isLaunch) {
        SentrySamplerDecision *decision =
            [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                              forSampleRate:@1
                                             withSampleRand:@0.2];
        configuration = [[SentryProfileConfiguration alloc]
            initContinuousProfilingV2WaitingForFullDisplay:YES
                                           samplerDecision:decision
                                            profileOptions:options];
    } else {
        configuration = [[SentryProfileConfiguration alloc] initWithProfileOptions:options];
        [configuration reevaluateSessionSampleRate];
    }
    sentry_setProfileConfiguration(configuration);
    self.usesContinuousProfiler = YES;
}

- (SentryTransaction *)profiledTransactionOnHub:(SentryHubInternal *)hub
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:nil
                                                operation:@"test"
                                                  sampled:kSentrySampleDecisionYes];
    SentryTracerConfiguration *configuration = [[SentryTracerConfiguration alloc] init];
    configuration.profilesSamplerDecision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:@1
                                         withSampleRand:@0.2];
    SentryTracer *tracer = [[SentryTracer alloc] initWithTransactionContext:context
                                                                        hub:hub
                                                              configuration:configuration];
    XCTAssertNotNil(tracer.profilerReferenceID);
    if (!self.usesContinuousProfiler) {
        self.traceProfiler = [SentryTraceProfiler getCurrentProfiler];
        XCTAssertNotNil(self.traceProfiler);
    }
    return [[SentryTransaction alloc] initWithTrace:tracer children:@[]];
}

- (void)populateTraceProfileState
{
    SentryProfilerState *state = [[SentryProfilerState alloc] init];
    [state mutate:^(SentryProfilerMutableState *mutableState) {
        [mutableState.frames addObject:@ { @"instruction_addr" : @"0x0000000000000001" }];
        [mutableState.stacks addObject:@[ @0 ]];
        mutableState.threadMetadata[@"1"] = [@ { @"name" : @"main" } mutableCopy];
        for (NSNumber *timestamp in @[ @200, @300 ]) {
            SentrySample *sample = [[SentrySample alloc] init];
            sample.absoluteTimestamp = timestamp.unsignedLongLongValue;
            sample.threadID = 1;
            sample.stackIndex = @0;
            [mutableState.samples addObject:sample];
        }
    }];
    self.traceProfiler.state = state;
}
#endif
@end
