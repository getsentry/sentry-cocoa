#import "SentryProfileTimeseries.h"
#import <XCTest/XCTest.h>

#if SENTRY_UIKIT_AVAILABLE && SENTRY_TARGET_PROFILING_SUPPORTED

@interface SentryProfileTimeseriesTests : XCTestCase

@end

@implementation SentryProfileTimeseriesTests {
    uint64_t startSystemTime;
    uint64_t endSystemTime;
}

- (void)setUp
{
    [super setUp];
    startSystemTime = 1000000000; // 1 second in nanoseconds
    endSystemTime = 3000000000; // 3 seconds in nanoseconds
}

#    pragma mark - sentry_sliceTraceProfileGPUData Tests

- (void)testSliceTraceProfileGPUData_WithValueKey_ReturnsCorrectEntries
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime + 500000000), // 1.5s
            @"value" : @(60.0)
        },
        @{
            @"timestamp" : @(startSystemTime + 1000000000), // 2s
            @"value" : @(30.0)
        },
        @{
            @"timestamp" : @(startSystemTime + 1500000000), // 2.5s
            @"value" : @(120.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, NO);

    // -- Assert --
    XCTAssertEqual(result.count, 3);

    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"500000000");
    XCTAssertEqualObjects(result[0][@"value"], @(60.0));

    XCTAssertEqualObjects(result[1][@"elapsed_since_start_ns"], @"1000000000");
    XCTAssertEqualObjects(result[1][@"value"], @(30.0));

    XCTAssertEqualObjects(result[2][@"elapsed_since_start_ns"], @"1500000000");
    XCTAssertEqualObjects(result[2][@"value"], @(120.0));
}

- (void)testSliceTraceProfileGPUData_WithNSNullValue_ExcludesNSNull
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime + 500000000), // 1.5s
            @"value" : [NSNull null] // NSNull represents nil in collections
        },
        @{
            @"timestamp" : @(startSystemTime + 1000000000), // 2s
            @"value" : @(30.0) // Valid value for comparison
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, NO);

    // -- Assert --
    XCTAssertEqual(result.count, 2);

    // Verify first entry (with nil value) - NSNull is excluded from the value key
    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"500000000");
    XCTAssertNil(result[0][@"value"]);

    // Verify second entry (with valid value)
    XCTAssertEqualObjects(result[1][@"elapsed_since_start_ns"], @"1000000000");
    XCTAssertEqualObjects(result[1][@"value"], @(30.0));
}

- (void)testSliceTraceProfileGPUData_WithMissingValueKey_ExcludesValueKey
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime + 500000000) // 1.5s
            // No 'value' key at all
        },
        @{
            @"timestamp" : @(startSystemTime + 1000000000), // 2s
            @"value" : @(30.0) // Valid value for comparison
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, NO);

    // -- Assert --
    XCTAssertEqual(result.count, 2);

    // Verify first entry (missing value key) - should not include value key
    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"500000000");
    XCTAssertNil(result[0][@"value"]);

    // Verify second entry (with valid value)
    XCTAssertEqualObjects(result[1][@"elapsed_since_start_ns"], @"1000000000");
    XCTAssertEqualObjects(result[1][@"value"], @(30.0));
}

- (void)testSliceTraceProfileGPUData_EmptyArray_ReturnsEmptyArray
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, NO);

    // -- Assert --
    XCTAssertEqual(result.count, 0);
}

- (void)testSliceTraceProfileGPUData_TimestampsOutsideRange_FiltersCorrectly
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime - 500000000), // Before start
            @"value" : @(60.0)
        },
        @{
            @"timestamp" : @(startSystemTime + 500000000), // Within range
            @"value" : @(30.0)
        },
        @{
            @"timestamp" : @(endSystemTime + 500000000), // After end
            @"value" : @(120.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, NO);

    // -- Assert --
    // Should only include the middle entry that's within the time range
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"500000000");
    XCTAssertEqualObjects(result[0][@"value"], @(30.0));
}

- (void)testSliceTraceProfileGPUData_UseMostRecentRecording_WithEmptyResult
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime - 500000000), // Before start
            @"value" : @(60.0)
        },
        @{
            @"timestamp" : @(endSystemTime + 500000000), // After end
            @"value" : @(120.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, YES);

    // -- Assert --
    // Should include the most recent predecessor value
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"0");
    XCTAssertEqualObjects(result[0][@"value"], @(60.0));
}

- (void)testSliceTraceProfileGPUData_UseMostRecentRecording_WithExistingResults
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime - 500000000), // Before start
            @"value" : @(60.0)
        },
        @{
            @"timestamp" : @(startSystemTime + 500000000), // Within range
            @"value" : @(30.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, YES);

    // -- Assert --
    // Should not add the predecessor value since we already have results
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"500000000");
    XCTAssertEqualObjects(result[0][@"value"], @(30.0));
}

- (void)testSliceTraceProfileGPUData_UseMostRecentRecording_WithNSNullPredecessor
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime - 500000000), // Before start
            @"value" : [NSNull null] // NSNull value
        },
        @{
            @"timestamp" : @(endSystemTime + 500000000), // After end
            @"value" : @(120.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, YES);

    // -- Assert --
    // Should not add any entry since NSNull is treated as no data
    XCTAssertEqual(result.count, 0);
}

- (void)testSliceTraceProfileGPUData_UseMostRecentRecording_WithTrueNilPredecessor
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime - 500000000) // Before start, no value key
        },
        @{
            @"timestamp" : @(endSystemTime + 500000000), // After end
            @"value" : @(120.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, YES);

    // -- Assert --
    // Should not add any entry since predecessor has no value key (truly nil)
    XCTAssertEqual(result.count, 0);
}

- (void)testSliceTraceProfileGPUData_BoundaryTimestamps_IncludesCorrectly
{
    // -- Arrange --
    SentryFrameInfoTimeSeries *frameInfo = @[
        @{
            @"timestamp" : @(startSystemTime), // Exactly at start
            @"value" : @(60.0)
        },
        @{
            @"timestamp" : @(endSystemTime), // Exactly at end
            @"value" : @(30.0)
        }
    ];

    // -- Act --
    NSArray<SentrySerializedMetricEntry *> *result
        = sentry_sliceTraceProfileGPUData(frameInfo, startSystemTime, endSystemTime, NO);

    // -- Assert --
    // Both boundary timestamps should be included
    XCTAssertEqual(result.count, 2);

    XCTAssertEqualObjects(result[0][@"elapsed_since_start_ns"], @"0");
    XCTAssertEqualObjects(result[0][@"value"], @(60.0));

    XCTAssertEqualObjects(result[1][@"elapsed_since_start_ns"], @"2000000000");
    XCTAssertEqualObjects(result[1][@"value"], @(30.0));
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED