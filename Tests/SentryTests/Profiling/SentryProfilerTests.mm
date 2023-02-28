#import "SentryProfiler+Test.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

using namespace sentry::profiling;

#    import "SentryProfiler.h"
#    import <XCTest/XCTest.h>
#    import <execinfo.h>

@interface SentryProfilerTests : XCTestCase
@end

@implementation SentryProfilerTests

- (void)testParseFunctionNameWithFixedInput
{
    const auto functionName = parseBacktraceSymbolsFunctionName(
        "2   UIKitCore                           0x00000001850d97ac -[UIFieldEditor "
        "_fullContentInsetsFromFonts] + 160");
    XCTAssertEqualObjects(functionName, @"-[UIFieldEditor _fullContentInsetsFromFonts]");
}

- (void)testParseFunctionNameWithBacktraceSymbolsInput
{
    void *buffer[64];
    const auto nptrs = backtrace(buffer, 64);
    if (nptrs <= 0) {
        XCTFail("Failed to collect a backtrace");
        return;
    }

    const auto symbols = backtrace_symbols(buffer, nptrs);
    XCTAssertEqualObjects(parseBacktraceSymbolsFunctionName(symbols[0]),
        @"-[SentryProfilerTests testParseFunctionNameWithBacktraceSymbolsInput]");
}

- (void)testProfilerCanBeInitializedOnMainThread
{
    XCTAssertNotNil([[SentryProfiler alloc] init]);
}

- (void)testProfilerCanBeInitializedOffMainThread
{
    const auto expectation = [self expectationWithDescription:@"background initializing profiler"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        XCTAssertNotNil([[SentryProfiler alloc] init]);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *_Nullable error) { NSLog(@"%@", error); }];
}

- (void)testProfilerPayload
{
    const auto resolvedThreadMetadata =
        [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
    const auto resolvedQueueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    const auto resolvedStacks = [NSMutableArray<NSMutableArray<NSNumber *> *> array];
    const auto resolvedSamples = [NSMutableArray<SentrySampleEntry *> array];
    const auto resolvedFrames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
    const auto frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];

    // record an initial backtrace

    ThreadMetadata threadMetadata1;
    threadMetadata1.name = "testThread";
    threadMetadata1.threadID = 12345568910;
    threadMetadata1.priority = 666;

    QueueMetadata queueMetadata1;
    queueMetadata1.address = 9876543210;
    queueMetadata1.label = std::make_shared<std::string>("testQueue");

    const auto addresses1 = std::vector<std::uintptr_t>({ 123, 456, 789 });

    Backtrace backtrace1;
    backtrace1.threadMetadata = threadMetadata1;
    backtrace1.queueMetadata = queueMetadata1;
    backtrace1.absoluteTimestamp = 5;
    backtrace1.addresses = addresses1;

    processBacktrace(backtrace1, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
        resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);

    // record a second backtrace with some common addresses to test frame deduplication

    ThreadMetadata threadMetadata2;
    threadMetadata2.name = "testThread";
    threadMetadata2.threadID = 12345568910;
    threadMetadata2.priority = 666;

    QueueMetadata queueMetadata2;
    queueMetadata2.address = 9876543210;
    queueMetadata2.label = std::make_shared<std::string>("testQueue");

    const auto addresses2 = std::vector<std::uintptr_t>({ 777, 888, 789 });

    Backtrace backtrace2;
    backtrace2.threadMetadata = threadMetadata2;
    backtrace2.queueMetadata = queueMetadata2;
    backtrace2.absoluteTimestamp = 5;
    backtrace2.addresses = addresses2;

    processBacktrace(backtrace2, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
        resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);

    // record a third backtrace that's identical to the second to test stack deduplication

    processBacktrace(backtrace2, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
        resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);

    XCTAssertEqual(resolvedFrames.count, 5UL);
    XCTAssertEqual(resolvedStacks.count, 2UL);
    XCTAssertEqual(resolvedSamples.count, 3UL);
}

@end

#endif
