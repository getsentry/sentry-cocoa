#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryEvent+Private.h"
#    import "SentryHub+Test.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfiler+Test.h"
#    import "SentryProfilerMocks.h"
#    import "SentryProfilerSerialization+Test.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryScreenFrames.h"
#    import "SentryThread.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext+Private.h"

using namespace sentry::profiling;

#    import "SentryProfiler+Private.h"
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
    SentryProfilerState *state = [[SentryProfilerState alloc] init];
    // generate a large timeseries of simulated data

    const auto threads = 5;
    const auto samplesPerThread = 10000;
    auto sampleIdx = 0;
    for (auto thread = 0; thread < threads; thread++) {
        // avoid overlapping any simulated data values
        const auto threadID = thread + threads;
        const auto threadPriority = thread + threads * 2;
        uint64_t address = thread + threads * 4;

        const auto threadName = [[NSString stringWithFormat:@"testThread-%d", thread]
            cStringUsingEncoding:NSUTF8StringEncoding];
        const auto addresses
            = std::vector<std::uintptr_t>({ address + 1, address + 2, address + 3 });

        auto backtrace = mockBacktrace(threadID, threadPriority, threadName, addresses);

        for (auto sample = 0; sample < samplesPerThread; sample++) {
            backtrace.absoluteTimestamp = sampleIdx; // simulate 1 sample per nanosecond
            [state appendBacktrace:backtrace];
            ++sampleIdx;
        }
    }

    // start submitting two types of concurrent operations:
    //     1. slice the timeseries bounded by a transaction
    //     2. add more samples

    const auto operations = 50;

    const auto startSystemTime = arc4random() % sampleIdx;
    const auto remainingTime = sampleIdx - startSystemTime;
    const auto minDuration = 10;
    const auto endSystemTime
        = startSystemTime + (arc4random() % (remainingTime - minDuration) + minDuration + 1);

    const auto sliceExpectation =
        [self expectationWithDescription:@"all slice operations complete"];
    sliceExpectation.expectedFulfillmentCount = operations;

    void (^sliceBlock)(void) = ^(void) {
        [state mutate:^(SentryProfilerMutableState *mutableState) {
            __unused const auto slice
                = sentry_slicedProfileSamples(mutableState.samples, startSystemTime, endSystemTime);
            [sliceExpectation fulfill];
        }];
    };

    const auto backtrace = mockBacktrace(
        12345568910, 666, "testThread", std::vector<std::uintptr_t>({ 777, 888, 789 }));

    const auto mutateExpectation =
        [self expectationWithDescription:@"all mutating operations complete"];
    mutateExpectation.expectedFulfillmentCount = operations;

    void (^mutateBlock)(void) = ^(void) {
        [state mutate:^(
            __unused SentryProfilerMutableState *mutableState) { [mutateExpectation fulfill]; }];
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

/**
 * We received reports of crashes happening during serialization, which turned out to be caused by a
 * data race in the collections we use to store profiler information, which are block-enumerated by
 * NSJSONSerialization, which is not a thread-safe operation. So when the backtrace profiler
 * modified the same collection from another thread while the block enumeration was in progress, a
 * crash occurred. The solution is twofold:
 *   1. copy the data structures so that serialization works with a new instance that will never be
 * modified by the backtrace sampler thread
 *   2. force exclusive access to the data structures so that they are never modified during any
 * other operation, even the copy
 */
- (void)testProfilerMutationDuringSerialization
{
    SentryProfilerState *state = [[SentryProfilerState alloc] init];
    // initialize the data structures with some simulated data
    {
        // leave thread name as nil so it can be overwritten later
        auto backtrace
            = mockBacktrace(1, 2, nullptr, std::vector<std::uintptr_t>({ 0x4, 0x5, 0x6 }));

        backtrace.absoluteTimestamp = 1;
        [state appendBacktrace:backtrace];

        backtrace.absoluteTimestamp = 2;
        [state appendBacktrace:backtrace];
    }

    // serialize the data as if it were captured in a transaction envelope
    const auto profileData = [state copyProfilingData];

    const auto serialization = sentry_serializedProfileData(profileData, 1, 2,
        sentry_profilerTruncationReasonName(SentryProfilerTruncationReasonNormal), @{}, @[],
        [[SentryHub alloc] initWithClient:nil andScope:nil]
#    if SENTRY_HAS_UIKIT
        ,
        [[SentryScreenFrames alloc] initWithTotal:5
                                           frozen:6
                                             slow:7
                              slowFrameTimestamps:@[]
                            frozenFrameTimestamps:@[]
                              frameRateTimestamps:@[]]
#    endif // SENTRY_HAS_UIKIT
    );

    // cause the data structures to be modified again: add new addresses
    {
        const auto backtrace = mockBacktrace(
            12345568910, 666, "newThread-2", std::vector<std::uintptr_t>({ 0x777, 0x888, 0x999 }));
        [state appendBacktrace:backtrace];
    }

    // cause the data structures to be modified again: overwrite previous thread metadata
    // subdictionary contents
    {
        auto backtrace
            = mockBacktrace(1, 2, "testThread-1", std::vector<std::uintptr_t>({ 0x4, 0x5, 0x6 }));
        backtrace.absoluteTimestamp = 6;
        [state appendBacktrace:backtrace];
    }

    // ensure the serialization's copied data structures don't contain the new addresses
    NSArray<NSDictionary<NSString *, id> *> *frames = serialization[@"profile"][@"frames"];
    XCTAssertEqual(frames.count, 3UL,
        @"New frames appeared in the data structure that should have been copied for serialization "
        @"and should no longer be modifiable from the backtrace sampler thread.");

    const auto index =
        [frames indexOfObjectPassingTest:^BOOL(NSDictionary<NSString *, id> *_Nonnull obj,
            __unused NSUInteger idx, __unused BOOL *_Nonnull stop) {
            NSString *address = obj[@"instruction_addr"];
            const auto unexpected =
                @[ @"0x0000000000000777", @"0x0000000000000888", @"0x0000000000000999" ];
            return [unexpected containsObject:address];
        }];
    XCTAssertEqual(index, NSNotFound,
        @"The data structures copied for serialization should not be modified with subsequent "
        @"calls from the backtrace sampler. The new backtrace addresses should not appear in the "
        @"copies of the profiling data structures after calling the serialization function.");

    // ensure the serialization's copied data structures don't get the updated thread info
    XCTAssertNil(serialization[@"profile"][@"thread_metadata"][@"1"][@"name"],
        @"Thread metadata had a nil thread name at time of serialization, but modification "
        @"overwrote it later and that change propagated to the serialization copy of the profiling "
        @"data structure.");
}

- (void)testProfilerPayload
{
    SentryProfilerState *state = [[SentryProfilerState alloc] init];

    // record an initial backtrace
    const auto backtrace1 = mockBacktrace(
        12345568910, 666, "testThread", std::vector<std::uintptr_t>({ 0x123, 0x456, 0x789 }));
    [state appendBacktrace:backtrace1];

    // record a second backtrace with some common addresses to test frame deduplication
    const auto backtrace2 = mockBacktrace(
        12345568910, 666, "testThread", std::vector<std::uintptr_t>({ 0x777, 0x888, 0x789 }));
    [state appendBacktrace:backtrace2];

    // record a third backtrace that's identical to the second to test stack/frame deduplication
    [state appendBacktrace:backtrace2];

    [state mutate:^(SentryProfilerMutableState *mutableState) {
        XCTAssertEqual(mutableState.frames.count, 5UL);
        const auto expectedOrdered = @[
            @"0x0000000000000123", @"0x0000000000000456", @"0x0000000000000789",
            @"0x0000000000000777", @"0x0000000000000888"
        ];
        [mutableState.frames
            enumerateObjectsUsingBlock:^(NSDictionary<NSString *, id> *_Nonnull actualFrame,
                NSUInteger idx, __unused BOOL *_Nonnull stop) {
                XCTAssert([actualFrame[@"instruction_addr"] isEqualToString:expectedOrdered[idx]]);
            }];

        XCTAssertEqual(mutableState.stacks.count, 2UL);
        XCTAssertEqual(mutableState.samples.count, 3UL);
    }];
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
