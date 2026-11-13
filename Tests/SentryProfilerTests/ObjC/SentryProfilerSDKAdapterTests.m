@import XCTest;
#import "SentryDefaultProfilerSDKBackend.h"
#import "SentryFileManagerHelper.h"
#import "SentryMemory.h"
#import "SentryProfiler+Private.h"
#import "SentryProfilerDeliveryBridge.h"
#import "SentryProfilerSDKAdapter.h"
#import "SentryProfilerState.h"
#import "SentryProfilerTestConditionals.h"
#import "SentryProfilingLog.h"
#import "SentryProfilingSwiftHelpers.h"
#import "SentrySDK+Private.h"
#import <objc/runtime.h>
#if SWIFT_PACKAGE
#    import "SentrySwift.h"
#else
@import Sentry;
#endif

#if SENTRY_PROFILER_TESTS_SUPPORTED
@interface TestProfilingLogger : NSObject <SentryProfilingLogger>
@property (nonatomic) BOOL enabled;
@property (nonatomic) SentryProfilingLogLevel level;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *file;
@property (nonatomic) NSUInteger line;
@end

@implementation TestProfilingLogger
- (BOOL)shouldLog:(SentryProfilingLogLevel)level
{
    return self.enabled;
}
- (void)log:(SentryProfilingLogLevel)level
    message:(NSString *)message
       file:(NSString *)file
       line:(NSUInteger)line
{
    self.level = level;
    self.message = message;
    self.file = file;
    self.line = line;
}
@end

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
#if SENTRY_PROFILER_TESTS_SUPPORTED
@property (nonatomic, strong) id<SentryProfilingLogger> previousLogger;
#endif
@end

@implementation SentryProfilerSDKAdapterTests

#if SENTRY_PROFILER_TESTS_SUPPORTED

- (void)setUp
{
    [super setUp];
    self.previousLogger = SentryProfilingLog.logger;
}

- (void)tearDown
{
    SentryProfilingLog.logger = self.previousLogger;
    self.previousLogger = nil;
    [super tearDown];
}

- (void)testProfilingLogger_whenNotConfigured_shouldNotEvaluateArguments
{
    // -- Arrange --
    SentryProfilingLog.logger = nil;
    NSUInteger evaluations = 0;

    // -- Act --
    SENTRY_PROFILING_LOG_ERROR(@"%lu", ++evaluations);

    // -- Assert --
    XCTAssertEqual(evaluations, 0U);
}

- (void)testProfilingLogger_whenDisabled_shouldNotEvaluateArguments
{
    // -- Arrange --
    TestProfilingLogger *logger = [[TestProfilingLogger alloc] init];
    SentryProfilingLog.logger = logger;
    NSUInteger evaluations = 0;

    // -- Act --
    SENTRY_PROFILING_LOG_DEBUG(@"%lu", ++evaluations);

    // -- Assert --
    XCTAssertEqual(evaluations, 0U);
    XCTAssertNil(logger.message);
}

- (void)testProfilingLogger_whenEnabled_shouldForwardFormattedMessageAndLocation
{
    // -- Arrange --
    TestProfilingLogger *logger = [[TestProfilingLogger alloc] init];
    logger.enabled = YES;
    SentryProfilingLog.logger = logger;
    NSUInteger evaluations = 0;

    // -- Act --
    NSUInteger line = __LINE__ + 1;
    SENTRY_PROFILING_LOG_WARN(@"sample %lu", ++evaluations);

    // -- Assert --
    XCTAssertEqual(evaluations, 1U);
    XCTAssertEqual(logger.level, SentryProfilingLogLevelWarning);
    XCTAssertEqualObjects(logger.message, @"sample 1");
    XCTAssertEqualObjects(logger.file, @(__FILE__));
    XCTAssertEqual(logger.line, line);
}

- (void)testProfilingLogger_whenOwnerReleasesLogger_shouldNotRetainIt
{
    // -- Arrange --
    @autoreleasepool {
        TestProfilingLogger *logger = [[TestProfilingLogger alloc] init];
        SentryProfilingLog.logger = logger;
        XCTAssertEqual(SentryProfilingLog.logger, logger);
    }

    // -- Assert --
    XCTAssertNil(SentryProfilingLog.logger);
}

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
        [SentrySDKInternal load];
        [SentryLaunchProfiling startLaunchProfile];

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

- (void)testProfilingAdapter_whenBackendReleased_shouldKeepSnapshottedMemoryReaderCallable
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    SentryProfilingMemoryReader reader = NULL;
    __weak SentryDefaultProfilerSDKBackend *weakBackend;
    @autoreleasepool {
        SentryDefaultProfilerSDKBackend *backend = [[SentryDefaultProfilerSDKBackend alloc] init];
        weakBackend = backend;
        [adapter setTarget:backend];
        reader = [adapter memoryReader];
    }
    int value = 123;

    // -- Act --
    BOOL readable = reader != NULL && reader(&value, sizeof(value));

    // -- Assert --
    XCTAssertNil(weakBackend);
    XCTAssertNil(adapter.target);
    XCTAssertTrue(reader == sentryMemoryIsReadable);
    XCTAssertTrue(readable);
    XCTAssertTrue([adapter memoryReader] == NULL);
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
    XCTAssertTrue([adapter memoryReader] == NULL);
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
