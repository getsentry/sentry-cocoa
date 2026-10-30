#import "SentryProfilerTestConditionals.h"

#if SENTRY_PROFILER_TESTS_SUPPORTED

#    import "SentryContinuousProfiler+Test.h"
#    import "SentryEvent+Private.h"
#    import "SentryHub.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerMocks.h"
#    import "SentryProfilerSerialization+Test.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentrySwift.h"
#    import "SentryThread.h"
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

- (void)testParseFunctionNameWithInvalidUTF8Input
{
    // Arrange
    // Create an invalid UTF-8 sequence: 0xFF is not a valid start byte in UTF-8
    const char invalidUTF8[] = { (char)0xFF, (char)0xFE, (char)0xFD, 0x00 };

    // Act
    // Parse the invalid UTF-8 symbol - should handle failure gracefully
    NSString *result = parseBacktraceSymbolsFunctionName(invalidUTF8);

    // Assert
    // Should return "<unknown>" when stringWithUTF8String fails
    XCTAssertEqualObjects(result, @"<unknown>");
}

- (void)testTraceProfilerCanBeInitializedOnMainThread
{
    XCTAssertNotNil([[SentryProfiler alloc] initWithMode:SentryProfilerModeTrace]);
}

- (void)testTraceProfilerCanBeInitializedOffMainThread
{
    const auto expectation = [self expectationWithDescription:@"background initializing profiler"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        XCTAssertNotNil([[SentryProfiler alloc] initWithMode:SentryProfilerModeTrace]);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *_Nullable error) { NSLog(@"%@", error); }];
}

- (void)testProfilerCanBeInitializedOnMainThread
{
    XCTAssertNotNil([[SentryProfiler alloc] initWithMode:SentryProfilerModeContinuous]);
}

/**
 * Given initialization on a background queue,
 * when a continuous profiler is created,
 * then sampling starts without requiring initialization on the main thread.
 */
- (void)testInitWithContinuousMode_whenCalledOffMainThread_shouldStartProfiler
{
    // -- Arrange --
    const auto expectation = [self expectationWithDescription:@"background initializing profiler"];

    // -- Act --
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        SentryProfiler *profiler =
            [[SentryProfiler alloc] initWithMode:SentryProfilerModeContinuous];

        // -- Assert --
        XCTAssertTrue(profiler.isRunning);
        [profiler stopForReason:SentryProfilerTruncationReasonNormal];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

/**
 * Given a snapshot of collected samples,
 * when live state receives another sample and is cleared,
 * then slicing the snapshot still returns the original samples in the requested time range.
 * This protects data used for profile processing after the live buffer changes. It tests snapshot
 * isolation, not concurrent lock exclusion.
 */
- (void)testSliceProfileSamples_whenStateChangesAfterSnapshot_shouldPreserveOriginalSamples
{
    // -- Arrange --
    SentryProfilerState *state = [[SentryProfilerState alloc] init];
    auto backtrace = mockBacktrace(1, 2, "main", std::vector<std::uintptr_t>({ 0x1, 0x2, 0x3 }));
    for (uint64_t timestamp : { 10, 20, 30, 40, 50 }) {
        backtrace.absoluteTimestamp = timestamp;
        [state appendBacktrace:backtrace];
    }
    const auto snapshot = [state copyProfilingData];
    NSArray<SentrySample *> *snapshotSamples = snapshot[@"profile"][@"samples"];

    // -- Act --
    backtrace.absoluteTimestamp = 60;
    [state appendBacktrace:backtrace];
    [state clear];
    const auto slice = sentry_slicedProfileSamples(snapshotSamples, 20, 60);

    // -- Assert --
    NSArray<SentrySample *> *currentSamples = [state copyProfilingData][@"profile"][@"samples"];
    XCTAssertEqual(currentSamples.count, 0UL);
    XCTAssertEqual(snapshotSamples.count, 5UL);
    XCTAssertEqual(slice.count, 4UL);
    NSArray<NSNumber *> *expectedTimestamps = @[ @20, @30, @40, @50 ];
    if (slice.count != expectedTimestamps.count) {
        return;
    }
    [slice enumerateObjectsUsingBlock:^(SentrySample *sample, NSUInteger idx, __unused BOOL *stop) {
        XCTAssertEqual(sample.absoluteTimestamp, expectedTimestamps[idx].unsignedLongLongValue);
        XCTAssertEqual(sample.threadID, 1ULL);
        XCTAssertEqualObjects(sample.stackIndex, @0);
    }];
    XCTAssertEqualObjects(snapshot[@"profile"][@"stacks"], (@[ @[ @0, @1, @2 ] ]));
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

    const auto serialization = sentry_serializedTraceProfileData(profileData, 1, 2,
        sentry_profilerTruncationReasonName(SentryProfilerTruncationReasonNormal), @{ }, @[],
        [[SentryHubInternal alloc] initWithClient:nil andScope:nil]
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

#endif // SENTRY_PROFILER_TESTS_SUPPORTED
