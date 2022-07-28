#import "SentryProcessInfo.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

// To get around the 15 minute timeout per test case on Sauce Labs. See develop-docs/README.md.
static NSUInteger SentrySDKPerformanceBenchmarkTestCases = 5;
static NSUInteger SentrySDKPerformanceBenchmarkIterationsPerTestCase = 4;

// All results are aggregated to analyse after completing the separate,
// dynamically generated test cases
static NSMutableArray *allResults;
static BOOL checkedAssertions = NO;

@interface SentrySDKPerformanceBenchmarkTests : XCTestCase

@end

@implementation SentrySDKPerformanceBenchmarkTests

/**
 * Dynamically add a test method to an XCTestCase class.
 * @see https://www.gaige.net/dynamic-xctests.html
 */
+ (BOOL)addInstanceMethodWithSelectorName:(NSString *)selectorName block:(void (^)(id))block
{
    NSParameterAssert(selectorName);
    NSParameterAssert(block);

    // See
    // http://stackoverflow.com/questions/6357663/casting-a-block-to-a-void-for-dynamic-class-method-resolution
    id impBlockForIMP = (__bridge id)(__bridge void *)(block);
    IMP myIMP = imp_implementationWithBlock(impBlockForIMP);
    SEL selector = NSSelectorFromString(selectorName);
    return class_addMethod(self, selector, myIMP, "v@:");
}

+ (void)initialize
{
    allResults = [NSMutableArray array];
    for (NSUInteger i = 0; i < SentrySDKPerformanceBenchmarkTestCases; i++) {
        [self addInstanceMethodWithSelectorName:[NSString stringWithFormat:@"testCPUBenchmark%lu",
                                                          (unsigned long)i]
                                          block:^(XCTestCase *testCase) {
                                              [allResults
                                                  addObjectsFromArray:[self _testCPUBenchmark]];
                                          }];
    }
}

- (void)tearDown
{
    if (allResults.count
        == SentrySDKPerformanceBenchmarkTestCases
            * SentrySDKPerformanceBenchmarkIterationsPerTestCase) {
        NSUInteger index = (NSUInteger)ceil(0.9 * allResults.count);
        NSNumber *p90 =
            [allResults sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
                return [a compare:b];
            }][index >= allResults.count ? allResults.count - 1 : index];
        XCTAssertLessThanOrEqual(
            p90.doubleValue, 5, @"Profiling P90 overhead should remain under 5%%.");
        checkedAssertions = YES;
    }

    [super tearDown];
}

+ (void)tearDown
{
    if (!checkedAssertions) {
        @throw @"Did not perform assertion checks, might not have completed all benchmark trials.";
    }
}

+ (NSArray<NSNumber *> *)_testCPUBenchmark
{
    XCTSkipIf(isSimulator() && !isDebugging());

    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger j = 0; j < SentrySDKPerformanceBenchmarkIterationsPerTestCase; j++) {
        XCUIApplication *app = [[XCUIApplication alloc] init];
        app.launchArguments =
            [app.launchArguments arrayByAddingObject:@"--io.sentry.test.benchmarking"];
        [app launch];
        [app.buttons[@"Performance scenarios"] tap];

        // after navigating to the test, the test app will do CPU intensive work until hitting the
        // stop button. wait 15 seconds so that work can be done while the profiler does its thing,
        // and the benchmarking observation in the test app will record how much CPU time is used by
        // everything
        sleep(15);

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

        [results addObject:@(usagePercentage)];
    }

    return results;
}

@end
