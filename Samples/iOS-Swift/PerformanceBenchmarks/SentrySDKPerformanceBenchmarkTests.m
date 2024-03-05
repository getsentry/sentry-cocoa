#import "SentryProcessInfo.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

@interface SentrySDKPerformanceBenchmarkTests : XCTestCase

@end

@implementation SentrySDKPerformanceBenchmarkTests

- (void)setUp
{
    [super setUp];

    [[XCUIDevice sharedDevice] setOrientation:UIDeviceOrientationPortrait];
}

- (void)testCPUBenchmark
{
    XCTSkipIf(isSimulator() && !isDebugging());

    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger j = 0; j < 20; j++) {
        XCUIApplication *app = [[XCUIApplication alloc] init];
        app.launchArguments =
            [app.launchArguments arrayByAddingObject:@"--io.sentry.test.benchmarking"];
        [app launch];
        [app.tabBars[@"Tab Bar"].buttons[@"Transactions"] tap];

        [app.buttons[@"startTransactionMainThread"] tap];

        [app.tabBars[@"Tab Bar"].buttons[@"Profiling"] tap];

        [app.buttons[@"Benchmark start"] tap];

        // after navigating to the test, the test app will do CPU intensive work until hitting the
        // stop button. wait 15 seconds so that work can be done while the profiler does its thing,
        // and the benchmarking observation in the test app will record how much CPU time is used by
        // everything
        sleep(15);

        [app.buttons[@"io.sentry.iOS-Swift.button.benchmark-end"] tap];

        XCUIElement *textField = app.textFields[@"io.sentry.benchmark.value-marshaling-text-field"];
        if (![textField waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't find benchmark value marshaling text field.");
        }

        NSString *benchmarkValueString = textField.value;
        // SentryBenchmarking.retrieveBenchmarks returns nil if there aren't at least 2 samples to
        // use for calculating deltas
        XCTAssertFalse([benchmarkValueString isEqualToString:@"nil"],
            @"Failure to record enough CPU samples to calculate benchmark.");
        if (benchmarkValueString == nil) {
            XCTFail(@"No benchmark value received from the app.");
        }

        NSArray *values = [benchmarkValueString componentsSeparatedByString:@","];

        NSInteger profilerSystemTime = [values[0] integerValue];
        NSInteger profilerUserTime = [values[1] integerValue];
        NSInteger appSystemTime = [values[2] integerValue];
        NSInteger appUserTime = [values[3] integerValue];

        NSLog(@"[Sentry Benchmark] %ld,%ld,%ld,%ld", profilerSystemTime, profilerUserTime,
            appSystemTime, appUserTime);

        double usagePercentage
            = 100.0 * (profilerUserTime + profilerSystemTime) / (appUserTime + appSystemTime);

        XCTAssertNotEqual(usagePercentage, 0, @"Overhead percentage should be > 0%%");

        [results addObject:@(usagePercentage)];
    }
}

@end
