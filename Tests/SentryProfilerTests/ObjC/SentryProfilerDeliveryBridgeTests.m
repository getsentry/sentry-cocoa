@import XCTest;
#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    import "SentryDefaultProfilerSDKBackend.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfilerDeliveryBridge.h"
#    import "SentryProfilerDeliveryTestHub.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilerState.h"
#    import "SentrySDK+Private.h"
#    import "SentrySDKInternal+Tests.h"
#    import "SentryTracer+Private.h"
#    if SWIFT_PACKAGE
#        import "SentrySwift.h"
#    else
@import Sentry;
#    endif
#endif

@interface SentryProfilerDeliveryBridgeTests : XCTestCase
#if SENTRY_PROFILER_TESTS_SUPPORTED
@property (nonatomic, strong, nullable) SentryHubInternal *previousHub;
@property (nonatomic, strong, nullable) SentryProfileConfiguration *previousConfiguration;
@property (nonatomic) BOOL previouslyTracingLaunch;
#endif
@end

@implementation SentryProfilerDeliveryBridgeTests
#if SENTRY_PROFILER_TESTS_SUPPORTED
- (void)setUp
{
    [super setUp];
    self.previousHub = SentrySDKInternal.currentHub;
    self.previousConfiguration = sentry_getProfileConfiguration();
    self.previouslyTracingLaunch = SentryProfilerSDKAdapter.shared.isTracingAppLaunch;
    sentry_setProfileConfiguration(nil);
    SentryProfilerSDKAdapter.shared.isTracingAppLaunch = NO;
}

- (void)tearDown
{
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

- (void)testCaptureChunk_whenSnapshotProvided_shouldPreservePayloadAndEnvelopeIdentity
{
    // -- Arrange --
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil
                                                                                      andScope:nil];
    [hub.scope setEnvironment:@"delivery-scope"];
    [SentrySDKInternal setCurrentHub:hub];
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    SentryDefaultProfilerSDKBackend *backend = [[SentryDefaultProfilerSDKBackend alloc] init];
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
                               metrics:metrics
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

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
    SentryProfilerDeliveryTestHub *hub = [[SentryProfilerDeliveryTestHub alloc] initWithClient:nil
                                                                                      andScope:nil];
    [SentrySDKInternal setCurrentHub:hub];
    SentryDefaultProfilerSDKBackend *backend = [[SentryDefaultProfilerSDKBackend alloc] init];
    NSDictionary *state = [[[SentryProfilerState alloc] init] copyProfilingData];

    // -- Act --
    [backend captureProfileChunkWithID:@"0123456789abcdef0123456789abcdef"
                                  data:state
                               metrics:@{ @"unsupported" : [NSDate date] }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

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
                               metrics:@{ }
#    if SENTRY_HAS_UIKIT
                                frames:nil
#    endif
    ];

    // -- Assert --
    XCTAssertEqual(hub.envelopeCount, 0U);
}
#endif
@end
