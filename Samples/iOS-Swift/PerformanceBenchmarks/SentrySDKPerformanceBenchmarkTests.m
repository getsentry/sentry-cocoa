#import "SentryProcessInfo.h"
#import <objc/runtime.h>
#import <XCTest/XCTest.h>

// To get around the 15 minute timeout per test case on Sauce Labs.
static NSUInteger SentrySDKPerformanceBenchmarkTestCases = 1;
static NSUInteger SentrySDKPerformanceBenchmarkIterationsPerTestCase = 1;

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
+ (BOOL)addInstanceMethodWithSelectorName:(NSString *)selectorName block:(void (^)(id))block {
    NSParameterAssert(selectorName);
    NSParameterAssert(block);

    // See
    // http://stackoverflow.com/questions/6357663/casting-a-block-to-a-void-for-dynamic-class-method-resolution
    id impBlockForIMP = (__bridge id)(__bridge void *)(block);
    IMP myIMP = imp_implementationWithBlock(impBlockForIMP);
    SEL selector = NSSelectorFromString(selectorName);
    return class_addMethod(self, selector, myIMP, "v@:");
}

+ (void)initialize {
    allResults = [NSMutableArray array];
    for (NSUInteger i = 0; i < SentrySDKPerformanceBenchmarkTestCases; i++) {
        [self addInstanceMethodWithSelectorName:[NSString stringWithFormat:@"testCPUBenchmark%lu", (unsigned long)i] block:^(XCTestCase *testCase) {
            [allResults addObjectsFromArray:[self _testCPUBenchmark]];
        }];
    }
}

- (void)tearDown {
    if (allResults.count == SentrySDKPerformanceBenchmarkTestCases * SentrySDKPerformanceBenchmarkIterationsPerTestCase) {
        NSUInteger index = (NSUInteger)ceil(0.9 * allResults.count);
        NSNumber *p90 = [allResults sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
            return [a compare:b];
        }][index >= allResults.count ? allResults.count - 1 : index];
        XCTAssertLessThanOrEqual(p90.doubleValue, 5, @"Profiling P90 overhead should remain under 5%%.");
        checkedAssertions = YES;
    }

    [super tearDown];
}

+ (void)tearDown {
    if (!checkedAssertions) {
        @throw @"Did not perform assertion checks, might not have completed all benchmark trials.";
    }
}

+ (NSArray<NSNumber *> *)_testCPUBenchmark {
    XCTSkipIf(isSimulator() && !isDebugging());

    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger j = 0; j < SentrySDKPerformanceBenchmarkIterationsPerTestCase; j++) {
        XCUIApplication *app = [[XCUIApplication alloc] init];
        app.launchArguments = [app.launchArguments arrayByAddingObject:@"--io.sentry.test.benchmarking"];
        [app launch];
        [app.buttons[@"Performance scenarios"] tap];

        XCUIElement *startButton = app.buttons[@"Start test"];
        if (![startButton waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't find benchmark retrieval button.");
        }
        [startButton tap];

        sleep(15);

        XCUIElement *stopButton = app.buttons[@"Stop test"];
        if (![stopButton waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't find benchmark retrieval button.");
        }
        [stopButton tap];

        XCUIElement *textField = app.textFields[@"io.sentry.benchmark.value-marshaling-text-field"];
        if (![textField waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't find benchmark value marshaling text field.");
        }

        NSString *benchmarkValueString = textField.value;
        if (benchmarkValueString == nil) {
            XCTFail(@"No benchmark value received from the app.");
        }
        double usagePercentage = benchmarkValueString.doubleValue;

        // SentryBenchmarking.retrieveBenchmarks returns -1 if there aren't at least 2 samples to use for calculating deltas
        XCTAssert(usagePercentage > 0, @"Failure to record enough CPU samples to calculate benchmark.");
        
        [results addObject:@(usagePercentage)];
    }

    return results;
}

@end
