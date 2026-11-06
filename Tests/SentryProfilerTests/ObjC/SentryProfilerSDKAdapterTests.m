@import XCTest;
#import "SentryDefaultProfilerSDKBackend.h"
#import "SentryFileManagerHelper.h"
#import "SentryProfiler+Private.h"
#import "SentryProfilerSDKAdapter.h"
#import "SentryProfilerSerialization.h"
#import "SentryProfilerState.h"
#import "SentryProfilerTestConditionals.h"
#import "SentryProfilingSwiftHelpers.h"
#import "SentrySDK+Private.h"
#import <objc/runtime.h>
#if SWIFT_PACKAGE
#    import "SentrySwift.h"
#else
@import Sentry;
#endif

#if SENTRY_PROFILER_TESTS_SUPPORTED
@interface TestProfilingSDKBackend : SentryDefaultProfilerSDKBackend
@end

@implementation TestProfilingSDKBackend
- (NSDate *)date
{
    return [NSDate dateWithTimeIntervalSince1970:123];
}
@end
#endif

@interface SentryProfilerSDKAdapterTests : XCTestCase
@end

@implementation SentryProfilerSDKAdapterTests

#if SENTRY_PROFILER_TESTS_SUPPORTED

- (void)testLaunchProfiling_whenConfigurationMissing_shouldNotAccessDependencies
{
    // -- Arrange --
    removeAppLaunchProfilingConfigFile();
    Method method
        = class_getClassMethod(SentryDependencyContainer.class, @selector(sharedInstance));
    IMP original = method_getImplementation(method);
    __block NSUInteger dependencyAccesses = 0;
    IMP replacement = imp_implementationWithBlock(^SentryDependencyContainer *(id receiver) {
        dependencyAccesses++;
        return ((SentryDependencyContainer * (*)(id, SEL)) original)(
            receiver, @selector(sharedInstance));
    });
    method_setImplementation(method, replacement);

    @try {
        // -- Act --
        [SentryProfiler load];
        sentry_startLaunchProfile();

        // -- Assert --
        XCTAssertEqual(dependencyAccesses, 0U);
    } @finally {
        method_setImplementation(method, original);
        imp_removeBlock(replacement);
    }
}

- (void)testProfilingAdapter_whenConfigured_shouldForwardClock
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    TestProfilingSDKBackend *backend = [[TestProfilingSDKBackend alloc] init];
    [adapter setTarget:backend];

    // -- Act --
    NSDate *date = [adapter date];

    // -- Assert --
    XCTAssertEqualObjects(date, [NSDate dateWithTimeIntervalSince1970:123]);
}

- (void)testContinuousProfileEnvelope_whenEnrichmentUnavailable_shouldKeepProfileAndMetrics
{
    // -- Arrange --
    SentryProfilerState *state = [[SentryProfilerState alloc] init];
    NSDictionary *metrics = @{
        @"cpu_usage" :
            @ { @"unit" : @"percent", @"values" : @[ @{ @"timestamp" : @123, @"value" : @12 } ] }
    };

    // -- Act --
    SentryEnvelope *envelope = sentry_continuousProfileChunkEnvelope([[SentryId alloc] init],
        [state copyProfilingData], metrics, @[], SentrySDKInternal.currentHub
#    if SENTRY_HAS_UIKIT
        ,
        nil
#    endif
    );

    // -- Assert --
    XCTAssertNotNil(envelope);
    NSError *error = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:envelope.items.firstObject.data
                                                            options:0
                                                              error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(payload[@"profile"]);
    XCTAssertNil(payload[@"debug_meta"]);
    XCTAssertEqualObjects(payload[@"measurements"], metrics);
}

- (void)testProfilingAdapter_whenNoTarget_shouldNotScheduleWork
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    __block BOOL called = NO;

    // -- Act --
    [adapter dispatchAsync:^{ called = YES; }];
    [adapter dispatchAsyncOnMainIfNotMainThread:^{ called = YES; }];
    id<SentryProfilingCancellation> timer = [adapter scheduleTimerWithInterval:1
                                                                       repeats:NO
                                                                         block:^{ called = YES; }];

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
    XCTAssertNil([adapter date]);
}

- (void)testProfilingAdapter_whenContainerInitializedBeforeSDKStart_shouldUseContainerDependencies
{
    // -- Arrange --
    (void)SentryDependencyContainer.sharedInstance;
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
    (void)SentryDependencyContainer.sharedInstance;
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
}

#endif // SENTRY_PROFILER_TESTS_SUPPORTED

@end
