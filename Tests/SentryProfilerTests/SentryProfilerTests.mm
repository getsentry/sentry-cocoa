#import "SentryEvent+Private.h"
#import "SentryId.h"
#import "SentryProfileTimeseries.h"
#import "SentryProfiler+Test.h"
#import "SentryProfilingConditionals.h"
#import "SentryThread.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext+Private.h"

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

- (void)testProfilerMutationDuringSlicing
{
    const auto resolvedThreadMetadata =
        [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
    const auto resolvedQueueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    const auto resolvedStacks = [NSMutableArray<NSArray<NSNumber *> *> array];
    const auto resolvedSamples = [NSMutableArray<SentrySample *> array];
    const auto resolvedFrames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
    const auto frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];

    // generate a large timeseries of simulated data

    const auto threads = 5;
    const auto samplesPerThread = 10000;
    auto sampleIdx = 0;
    for (auto thread = 0; thread < threads; thread++) {
        // avoid overlapping any simulated data values
        const auto threadID = thread + threads;
        const auto threadPriority = thread + threads * 2;
        const auto queue = thread + threads * 3;
        uint64_t address = thread + threads * 4;

        ThreadMetadata threadMetadata;
        threadMetadata.name = [[NSString stringWithFormat:@"testThread-%d", thread]
            cStringUsingEncoding:NSUTF8StringEncoding];
        threadMetadata.threadID = threadID;
        threadMetadata.priority = threadPriority;

        QueueMetadata queueMetadata;
        queueMetadata.address = queue;
        queueMetadata.label = std::make_shared<std::string>([[NSString
            stringWithFormat:@"testQueue-%d", thread] cStringUsingEncoding:NSUTF8StringEncoding]);

        Backtrace backtrace;
        backtrace.threadMetadata = threadMetadata;
        backtrace.queueMetadata = queueMetadata;
        backtrace.addresses
            = std::vector<std::uintptr_t>({ address + 1, address + 2, address + 3 });

        for (auto sample = 0; sample < samplesPerThread; sample++) {
            backtrace.absoluteTimestamp = sampleIdx; // simulate 1 sample per nanosecond
            processBacktrace(backtrace, resolvedThreadMetadata, resolvedQueueMetadata,
                resolvedSamples, resolvedStacks, resolvedFrames, frameIndexLookup,
                stackIndexLookup);
            ++sampleIdx;
        }
    }

    // start submitting two types of concurrent operations:
    //     1. slice the timeseries bounded by a transaction
    //     2. add more samples

    const auto operations = 50;

    const auto context = [[SentrySpanContext alloc] initWithOperation:@"test trace"];
    const auto trace = [[SentryTracer alloc] initWithContext:context];
    const auto transaction = [[SentryTransaction alloc] initWithTrace:trace children:@[]];
    transaction.startSystemTime = arc4random() % sampleIdx;
    const auto remainingTime = sampleIdx - transaction.startSystemTime;
    const auto minDuration = 10;
    transaction.endSystemTime = transaction.startSystemTime
        + (arc4random() % (remainingTime - minDuration) + minDuration + 1);

    const auto sliceExpectation =
        [self expectationWithDescription:@"all slice operations complete"];
    sliceExpectation.expectedFulfillmentCount = operations;

    void (^sliceBlock)(void) = ^(void) {
        __unused const auto slice = slicedProfileSamples(resolvedSamples, transaction);
        [sliceExpectation fulfill];
    };

    ThreadMetadata threadMetadata;
    threadMetadata.name = "testThread";
    threadMetadata.threadID = 12345568910;
    threadMetadata.priority = 666;

    QueueMetadata queueMetadata;
    queueMetadata.address = 9876543210;
    queueMetadata.label = std::make_shared<std::string>("testQueue");

    const auto addresses = std::vector<std::uintptr_t>({ 777, 888, 789 });

    Backtrace backtrace;
    backtrace.threadMetadata = threadMetadata;
    backtrace.queueMetadata = queueMetadata;
    backtrace.absoluteTimestamp = 5;
    backtrace.addresses = addresses;

    const auto mutateExpectation =
        [self expectationWithDescription:@"all mutating operations complete"];
    mutateExpectation.expectedFulfillmentCount = operations;

    void (^mutateBlock)(void) = ^(void) {
        processBacktrace(backtrace, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
            resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);
        [mutateExpectation fulfill];
    };

    const auto sliceOperations = [[NSOperationQueue alloc] init]; // concurrent queue

    const auto mutateOperations = [[NSOperationQueue alloc] init];
    mutateOperations.maxConcurrentOperationCount = 1; // serial queue

    for (auto operation = 0; operation < operations; operation++) {
        [sliceOperations addOperationWithBlock:sliceBlock];
        [mutateOperations addOperationWithBlock:mutateBlock];
    }

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testProfilerMutationDuringSerialization
{
    const auto resolvedThreadMetadata =
        [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
    const auto resolvedQueueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    const auto resolvedStacks = [NSMutableArray<NSArray<NSNumber *> *> array];
    const auto resolvedSamples = [NSMutableArray<SentrySample *> array];
    const auto resolvedFrames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
    const auto frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];

    // initialize the data structures with some simulated data
    {
        const auto threadID = 1;
        const auto threadPriority = 2;
        const auto queue = 3;
        uint64_t address = 4;

        ThreadMetadata threadMetadata;
        threadMetadata.name = [@"testThread-1" cStringUsingEncoding:NSUTF8StringEncoding];
        threadMetadata.threadID = threadID;
        threadMetadata.priority = threadPriority;

        QueueMetadata queueMetadata;
        queueMetadata.address = queue;
        queueMetadata.label = std::make_shared<std::string>(
            [@"testQueue-1" cStringUsingEncoding:NSUTF8StringEncoding]);

        Backtrace backtrace;
        backtrace.threadMetadata = threadMetadata;
        backtrace.queueMetadata = queueMetadata;
        backtrace.addresses
            = std::vector<std::uintptr_t>({ address + 1, address + 2, address + 3 });

        backtrace.absoluteTimestamp = 1;
        processBacktrace(backtrace, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
            resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);

        backtrace.absoluteTimestamp = 2;
        processBacktrace(backtrace, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
            resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);
    }

    // serialize the data as if it were captured in a transaction envelope
    const auto sampledProfile = [NSMutableDictionary<NSString *, id> dictionary];
    sampledProfile[@"samples"] = resolvedSamples;
    sampledProfile[@"stacks"] = resolvedStacks;
    sampledProfile[@"frames"] = resolvedFrames;
    sampledProfile[@"thread_metadata"] = resolvedThreadMetadata;
    sampledProfile[@"queue_metadata"] = resolvedQueueMetadata;
    const auto profileData = @{ @"profile" : sampledProfile };

    const auto context = [[SentrySpanContext alloc] initWithOperation:@"test trace"];
    const auto trace = [[SentryTracer alloc] initWithContext:context];
    const auto transaction = [[SentryTransaction alloc] initWithTrace:trace children:@[]];
    transaction.transaction = @"someTransaction";
    transaction.trace.transactionContext =
        [[SentryTransactionContext alloc] initWithName:@"someTransaction"
                                             operation:@"someOperation"];
    transaction.trace.transactionContext.threadInfo = [[SentryThread alloc] initWithThreadId:@1];
    transaction.startSystemTime = 1;
    transaction.endSystemTime = 2;

    const auto profileID = [[SentryId alloc] init];
    const auto serialization = serializedProfileData(profileData, transaction, profileID,
        profilerTruncationReasonName(SentryProfilerTruncationReasonNormal), @"test", @"someRelease",
        @{}, @[]);

    // cause the data structures to be modified again
    {
        ThreadMetadata threadMetadata;
        threadMetadata.name = "testThread";
        threadMetadata.threadID = 12345568910;
        threadMetadata.priority = 666;

        QueueMetadata queueMetadata;
        queueMetadata.address = 9876543210;
        queueMetadata.label = std::make_shared<std::string>("testQueue");

        const auto addresses = std::vector<std::uintptr_t>({ 0x777, 0x888, 0x999 });

        Backtrace backtrace;
        backtrace.threadMetadata = threadMetadata;
        backtrace.queueMetadata = queueMetadata;
        backtrace.absoluteTimestamp = 5;
        backtrace.addresses = addresses;

        processBacktrace(backtrace, resolvedThreadMetadata, resolvedQueueMetadata, resolvedSamples,
            resolvedStacks, resolvedFrames, frameIndexLookup, stackIndexLookup);
    }

    // ensure the serialization data structures don't contain the new values
    NSArray<NSDictionary<NSString *, id> *> *frames = serialization[@"profile"][@"frames"];
    XCTAssertEqual(frames.count, 3UL);

    const auto index =
        [frames indexOfObjectPassingTest:^BOOL(NSDictionary<NSString *, id> *_Nonnull obj,
            __unused NSUInteger idx, __unused BOOL *_Nonnull stop) {
            NSString *address = obj[@"instruction_addr"];
            const auto unexpected =
                @[ @"0x0000000000000777", @"0x0000000000000888", @"0x0000000000000999" ];
            return [unexpected containsObject:address];
        }];
    XCTAssertEqual(index, NSNotFound);
}

- (void)testProfilerPayload
{
    const auto resolvedThreadMetadata =
        [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
    const auto resolvedQueueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    const auto resolvedStacks = [NSMutableArray<NSArray<NSNumber *> *> array];
    const auto resolvedSamples = [NSMutableArray<SentrySample *> array];
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
