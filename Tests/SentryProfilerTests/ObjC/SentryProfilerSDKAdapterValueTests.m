@import XCTest;
#import "SentryProfilerSDKAdapter.h"
#import "SentryProfilerTestConditionals.h"
#import "TestProfilerValueBackend.h"

@interface SentryProfilerSDKAdapterValueTests : XCTestCase
@end

@implementation SentryProfilerSDKAdapterValueTests
#if SENTRY_PROFILER_TESTS_SUPPORTED
- (void)testTimestamp_whenClockInjected_shouldReturnPairedValues
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    TestProfilerValueBackend *backend = [[TestProfilerValueBackend alloc] init];
    backend.clock = [[TestProfilerValueClock alloc] init];
    [adapter setTarget:backend];

    // -- Act --
    SentryProfilingTimestamp timestamp = [adapter timestamp];

    // -- Assert --
    XCTAssertEqual(timestamp.systemTime, 456ULL);
    XCTAssertEqual(timestamp.dateInterval, 123);
}

- (void)testSystemMetrics_whenAvailable_shouldReturnGroupedReadings
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    TestProfilerValueBackend *backend = [[TestProfilerValueBackend alloc] init];
    backend.metrics = [[TestProfilerValueReadings alloc] init];
    [adapter setTarget:backend];

    // -- Act --
    SentryProfilingSystemMetrics *readings = [adapter systemMetrics];

    // -- Assert --
    XCTAssertEqualObjects(readings.cpuUsage, @25);
    XCTAssertEqualObjects(readings.memoryFootprintBytes, @1000);
    XCTAssertEqualObjects(readings.cpuEnergyUsage, @500);

    backend.metrics.failReadings = YES;
    readings = [adapter systemMetrics];
    XCTAssertNotNil(readings);
    XCTAssertNil(readings.cpuUsage);
    XCTAssertNil(readings.memoryFootprintBytes);
    XCTAssertNil(readings.cpuEnergyUsage);
}

- (void)testSystemMetrics_whenOneReadingMissing_shouldKeepAvailableReadings
{
    // -- Arrange & Act --
    SentryProfilingSystemMetrics *readings =
        [[SentryProfilingSystemMetrics alloc] initWithCPUUsage:@25
                                          memoryFootprintBytes:nil
                                                cpuEnergyUsage:@500];

    // -- Assert --
    XCTAssertNotNil(readings);
    XCTAssertEqualObjects(readings.cpuUsage, @25);
    XCTAssertNil(readings.memoryFootprintBytes);
    XCTAssertEqualObjects(readings.cpuEnergyUsage, @500);
}

- (void)testScheduleTimer_whenCancelled_shouldInvalidateUnderlyingTimer
{
    // -- Arrange --
    TestProfilerValueBackend *backend = [[TestProfilerValueBackend alloc] init];
    id<SentryProfilingCancellation> timer =
        [backend scheduleTimerWithInterval:3600
                                   repeats:NO
                                     block:^{ XCTFail(@"Cancelled timer must not fire"); }];
    XCTAssertTrue(backend.lastTimer.isValid);

    // -- Act --
    [timer cancel];

    // -- Assert --
    XCTAssertNotNil(timer);
    XCTAssertFalse(backend.lastTimer.isValid);
}

- (void)testValueOperations_whenNoTarget_shouldPreserveMissingBackendResults
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];

    // -- Act & Assert --
    XCTAssertNil([adapter serializedDebugImages]);
    XCTAssertNil([adapter systemMetrics]);
    SentryProfilingTimestamp timestamp = [adapter timestamp];
    XCTAssertEqual(timestamp.systemTime, 0ULL);
    XCTAssertEqual(timestamp.dateInterval, 0);
#    if SENTRY_HAS_UIKIT
    XCTAssertNil([adapter copyFrameMeasurements]);
#    endif
}

#    if SENTRY_HAS_UIKIT
- (void)testCopyFrameMeasurements_whenLegacyFramesProvided_shouldMapTimestampValues
{
    // -- Arrange --
    SentryProfilerSDKAdapter *adapter = [[SentryProfilerSDKAdapter alloc] init];
    TestProfilerValueBackend *backend = [[TestProfilerValueBackend alloc] init];
    backend.frames =
        [[SentryScreenFrames alloc] initWithTotal:3
                                           frozen:1
                                             slow:1
                              slowFrameTimestamps:@[ @{ @"timestamp" : @10, @"value" : @20 } ]
                            frozenFrameTimestamps:@[ @{ @"timestamp" : @30, @"value" : @40 } ]
                              frameRateTimestamps:@[ @{ @"timestamp" : @10, @"value" : @60 } ]];
    [adapter setTarget:backend];

    // -- Act --
    SentryProfilingFrameMeasurements *snapshot = [adapter copyFrameMeasurements];

    // -- Assert --
    XCTAssertEqualObjects(
        snapshot.slowFrameTimestamps, (@[ @{ @"timestamp" : @10, @"value" : @20 } ]));
    XCTAssertEqualObjects(
        snapshot.frozenFrameTimestamps, (@[ @{ @"timestamp" : @30, @"value" : @40 } ]));
    XCTAssertEqualObjects(
        snapshot.frameRateTimestamps, (@[ @{ @"timestamp" : @10, @"value" : @60 } ]));
    backend.frames = nil;
    XCTAssertNil([adapter copyFrameMeasurements]);
}

- (void)testFrameMeasurements_whenSourceChanges_shouldKeepSnapshot
{
    // -- Arrange --
    NSMutableArray *slowFrames =
        [NSMutableArray arrayWithObject:@{ @"timestamp" : @10, @"value" : @20 }];
    SentryProfilingFrameMeasurements *snapshot =
        [[SentryProfilingFrameMeasurements alloc] initWithSlowFrameTimestamps:slowFrames
                                                        frozenFrameTimestamps:@[]
                                                          frameRateTimestamps:@[]];

    // -- Act --
    [slowFrames removeAllObjects];

    // -- Assert --
    XCTAssertEqualObjects(
        snapshot.slowFrameTimestamps, (@[ @{ @"timestamp" : @10, @"value" : @20 } ]));
}
#    endif

#endif
@end
