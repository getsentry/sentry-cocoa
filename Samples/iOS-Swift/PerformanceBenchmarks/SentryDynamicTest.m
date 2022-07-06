#import <objc/runtime.h>
#import <XCTest/XCTest.h>

// To get around the 15 minute timeout per test case on Sauce Labs.
static NSUInteger SentrySDKPerformanceBenchmarkTestCases = 4;
static NSUInteger SentrySDKPerformanceBenchmarkIterationsPerTestCase = 5;

static NSMutableArray *allResults;

@interface SentrySDKPerformanceBenchmarkTests : XCTestCase

/**
 * Dynamically add a test method to an XCTestCase class.
 * @see https://www.gaige.net/dynamic-xctests.html
 */
+ (BOOL)addInstanceMethodWithSelectorName:(NSString *)selectorName block:(void (^)(id))block;

@end

@implementation SentrySDKPerformanceBenchmarkTests

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
        [self addInstanceMethodWithSelectorName:[NSString stringWithFormat:@"testCPUBenchmark%d", i] block:^(XCTestCase *testCase) {
            [allResults addObjectsFromArray:[self _testCPUBenchmark]];
        }];
    }
}

- (void)tearDown {
    if (allResults.count == SentrySDKPerformanceBenchmarkTestCases * SentrySDKPerformanceBenchmarkIterationsPerTestCase) {
        NSLog(@"All results begin");
        NSLog(@"%@", allResults);
        NSLog(@"All results end");
    }

    [super tearDown];
}

+ (BOOL)isSimulator {
    NSOperatingSystemVersion ios9 = {9, 0, 0};
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    if ([processInfo isOperatingSystemAtLeastVersion:ios9]) {
        NSDictionary<NSString *, NSString *> *environment = [processInfo environment];
        NSString *simulator = [environment objectForKey:@"SIMULATOR_DEVICE_NAME"];
        return simulator != nil;
    } else {
        UIDevice *currentDevice = [UIDevice currentDevice];
        return ([currentDevice.model rangeOfString:@"Simulator"].location != NSNotFound);
    }
}

+ (NSArray<NSNumber *> *)_testCPUBenchmark {
//    XCTSkipIf([self isSimulator]);

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
