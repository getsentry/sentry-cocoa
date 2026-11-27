@import SentryProfiling;
#import <XCTest/XCTest.h>

@interface SentryProfilingSystemMetricsTests : XCTestCase
@end

@implementation SentryProfilingSystemMetricsTests

- (void)testInit_whenReadingsAreProvided_shouldPreserveValues
{
    // -- Act --
    SentryProfilingSystemMetrics *metrics =
        [[SentryProfilingSystemMetrics alloc] initWithCPUUsage:@25
                                          memoryFootprintBytes:@1024
                                                cpuEnergyUsage:@42];

    // -- Assert --
    XCTAssertEqualObjects(metrics.cpuUsage, @25);
    XCTAssertEqualObjects(metrics.memoryFootprintBytes, @1024);
    XCTAssertEqualObjects(metrics.cpuEnergyUsage, @42);
}

- (void)testInit_whenReadingsAreUnavailable_shouldPreserveNil
{
    // -- Act --
    SentryProfilingSystemMetrics *metrics =
        [[SentryProfilingSystemMetrics alloc] initWithCPUUsage:nil
                                          memoryFootprintBytes:nil
                                                cpuEnergyUsage:nil];

    // -- Assert --
    XCTAssertNil(metrics.cpuUsage);
    XCTAssertNil(metrics.memoryFootprintBytes);
    XCTAssertNil(metrics.cpuEnergyUsage);
}

@end
