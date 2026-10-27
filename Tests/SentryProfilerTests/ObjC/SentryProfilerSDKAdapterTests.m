@import XCTest;
#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryProfilerSDKAdapter.h"
#import "SentryProfilerSerialization.h"
#import "SentryProfilerState.h"
#import "SentryProfilerTestConditionals.h"
#if SWIFT_PACKAGE
#    import "SentrySwift.h"
#else
@import Sentry;
#endif

#if SENTRY_PROFILER_TESTS_SUPPORTED
@interface TestProfilingSDKBackend : SentryDefaultProfilerSDKBackend
@property (nonatomic) NSUInteger launchStarts;
@end

@implementation TestProfilingSDKBackend
- (NSDate *)date
{
    return [NSDate dateWithTimeIntervalSince1970:123];
}
- (void)startLaunchProfile
{
    self.launchStarts++;
}
- (SentryDebugImageProvider *_Nullable)debugImageProvider
{
    return nil;
}
@end
#endif

@interface SentryProfilerSDKAdapterTests : XCTestCase
@end

@implementation SentryProfilerSDKAdapterTests

#if SENTRY_PROFILER_TESTS_SUPPORTED

- (void)testProfilingAdapter_whenConfigured_shouldForwardClockAndLaunchOperations
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    TestProfilingSDKBackend *backend = [[TestProfilingSDKBackend alloc] init];
    [adapter setTarget:backend];

    // -- Act --
    NSDate *date = [adapter date];
    [adapter startLaunchProfile];

    // -- Assert --
    XCTAssertEqualObjects(date, [NSDate dateWithTimeIntervalSince1970:123]);
    XCTAssertEqual(backend.launchStarts, 1UL);
}

- (void)testContinuousProfileEnvelope_whenEnrichmentUnavailable_shouldKeepProfileAndMetrics
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = SentryProfilerSDKAdapter.shared;
    id<SentryProfilerSDKBackend> previousBackend = adapter.target;
    TestProfilingSDKBackend *backend = [[TestProfilingSDKBackend alloc] init];
    SentryProfilerState *state = [[SentryProfilerState alloc] init];
    NSDictionary *metrics = @{
        @"cpu_usage" :
            @ { @"unit" : @"percent", @"values" : @[ @{ @"timestamp" : @123, @"value" : @12 } ] }
    };
    [adapter setTarget:backend];

    @try {
        // -- Act --
        SentryEnvelope *envelope = sentry_continuousProfileChunkEnvelope(
            [[SentryId alloc] init], [state copyProfilingData], metrics
#    if SENTRY_HAS_UIKIT
            ,
            nil
#    endif
        );

        // -- Assert --
        XCTAssertNotNil(envelope);
        NSError *error = nil;
        NSDictionary *payload =
            [NSJSONSerialization JSONObjectWithData:envelope.items.firstObject.data
                                            options:0
                                              error:&error];
        XCTAssertNil(error);
        XCTAssertNotNil(payload[@"profile"]);
        XCTAssertNil(payload[@"debug_meta"]);
        XCTAssertEqualObjects(payload[@"measurements"], metrics);
    } @finally {
        if (previousBackend != nil) {
            [adapter setTarget:previousBackend];
        } else {
            [adapter removeTarget:backend];
        }
    }
}

- (void)testProfilingAdapter_whenNoTarget_shouldNotScheduleWork
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    __block BOOL called = NO;

    // -- Act --
    [adapter dispatchAsync:^{ called = YES; }];
    [adapter dispatchAsyncOnMainIfNotMainThread:^{ called = YES; }];
    NSTimer *timer = [adapter scheduledTimerWithInterval:1 repeats:NO block:^{ called = YES; }];

    // -- Assert --
    XCTAssertFalse(called);
    XCTAssertNil(timer);
    XCTAssertNil([adapter date]);
    XCTAssertEqual([adapter systemTime], 0ULL);
}

- (void)testProfilingAdapter_whenTargetReplaced_shouldIgnoreOldTargetRemoval
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    SentryDefaultProfilerSDKBackend *oldBackend = [[SentryDefaultProfilerSDKBackend alloc] init];
    SentryDefaultProfilerSDKBackend *newBackend = [[SentryDefaultProfilerSDKBackend alloc] init];
    [adapter setTarget:oldBackend];

    // -- Act --
    [adapter setTarget:newBackend];
    [adapter removeTarget:oldBackend];

    // -- Assert --
    XCTAssertEqual(adapter.target, newBackend);
    [adapter removeTarget:newBackend];
    XCTAssertNil(adapter.target);
}

- (void)testProfilingAdapter_whenTargetReleased_shouldNotRetainIt
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    __weak SentryDefaultProfilerSDKBackend *weakBackend;

    // -- Act --
    @autoreleasepool {
        SentryDefaultProfilerSDKBackend *backend = [[SentryDefaultProfilerSDKBackend alloc] init];
        weakBackend = backend;
        [adapter setTarget:backend];
    }

    // -- Assert --
    XCTAssertNil(weakBackend);
    XCTAssertNil(adapter.target);
    XCTAssertNil(adapter.dateProvider);
}

- (void)testProfilingAdapter_whenBootstrappedBeforeSDKStart_shouldUseContainerDependencies
{
    // -- Arrange --
    sentry_bootstrapProfilerSDKAdapter();
    SentryProfilerSDKAdapter *adapter = SentryProfilerSDKAdapter.shared;
    id<SentryProfilerSDKBackend> backend = adapter.target;

    // -- Act --
    NSNotificationCenter *center = [[NSNotificationCenter alloc] init];
    SentryDependencyContainer.sharedInstance.notificationCenterWrapper = center;
    __block NSUInteger calls = 0;
    id observer = [center addObserverForName:@"profiling-adapter-test"
                                      object:nil
                                       queue:nil
                                  usingBlock:^(__unused NSNotification *notification) { calls++; }];
    [adapter postNotification:[NSNotification notificationWithName:@"profiling-adapter-test"
                                                            object:nil]];
    [center removeObserver:observer];

    // -- Assert --
    XCTAssertNotNil(backend);
    XCTAssertEqual(calls, 1UL);
    XCTAssertEqual(adapter.target, backend);
    [SentryDependencyContainer reset];
}

- (void)testProfilingAdapter_whenContainerReset_shouldReplaceBackendWithoutRetainingOldContainer
{
    // -- Arrange --
    sentry_bootstrapProfilerSDKAdapter();
    SentryProfilerSDKAdapter *adapter = SentryProfilerSDKAdapter.shared;
    __weak SentryDependencyContainer *oldContainer;
    __weak id<SentryProfilerSDKBackend> oldBackend;

    // -- Act --
    @autoreleasepool {
        oldContainer = SentryDependencyContainer.sharedInstance;
        oldBackend = adapter.target;
        [SentryDependencyContainer reset];
    }

    // -- Assert --
    XCTAssertNil(oldContainer);
    XCTAssertNil(oldBackend);
    XCTAssertNotNil(adapter.target);
    XCTAssertEqual(adapter.dateProvider, SentryDependencyContainer.sharedInstance.dateProvider);
}

#endif // SENTRY_PROFILER_TESTS_SUPPORTED

@end
