#import "SentryLog.h"
#import "SentryReachability+Private.h"
#import "SentryReachability.h"
#import <XCTest/XCTest.h>

void SentryConnectivityReset(void);

@interface TestSentryReachabilityObserver : NSObject <SentryReachabilityObserver>

@property (strong, nonatomic) XCTestExpectation *expectation;

@end
@implementation TestSentryReachabilityObserver

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation
{
    if (self = [super init]) {
        self.expectation = expectation;
    }
    return self;
}

- (void)connectivityChanged:(BOOL)connected typeDescription:(nonnull NSString *)typeDescription
{
    NSLog(@"Received connectivity notification: %i; type: %@", connected, typeDescription);
    [self.expectation fulfill];
}

@end

#if !TARGET_OS_WATCH
@interface SentryReachabilityTest : XCTestCase
@property (strong, nonatomic) SentryReachability *reachability;
@end

@implementation SentryReachabilityTest

- (void)setUp
{
    self.reachability = [[SentryReachability alloc] init];
    // Disable the reachability callbacks, cause we call the callbacks manually.
    // Otherwise, the reachability callbacks are called during later unrelated tests causing flakes.
    self.reachability.setReachabilityCallback = NO;
}

- (void)tearDown
{
    self.reachability = nil;
    SentryConnectivityReset();
}

- (void)testConnectivityRepresentations
{
    XCTAssertEqualObjects(SentryConnectivityNone, SentryConnectivityFlagRepresentation(0));
    XCTAssertEqualObjects(SentryConnectivityNone,
        SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsDirect));
#    if SENTRY_HAS_UIKIT
    // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
    XCTAssertEqualObjects(SentryConnectivityNone,
        SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN));
    XCTAssertEqualObjects(SentryConnectivityCellular,
        SentryConnectivityFlagRepresentation(
            kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable));
#    endif // SENTRY_HAS_UIKIT
    XCTAssertEqualObjects(SentryConnectivityWiFi,
        SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable));
    XCTAssertEqualObjects(SentryConnectivityWiFi,
        SentryConnectivityFlagRepresentation(
            kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsDirect));
}

- (void)testMultipleReachabilityObservers
{
    XCTestExpectation *aExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://sentry.io"];
    aExp.expectedFulfillmentCount = 5;
    TestSentryReachabilityObserver *a =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:aExp];
    [self.reachability addObserver:a];

    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsReachable, nil); // ignored, as it's the first callback
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsInterventionRequired, nil);

    XCTestExpectation *bExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://google.io"];
    bExp.expectedFulfillmentCount = 2;
    TestSentryReachabilityObserver *b =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:bExp];
    [self.reachability addObserver:b];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsInterventionRequired, nil);

    [self.reachability removeObserver:b];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    [self waitForExpectations:@[ aExp, bExp ] timeout:1.0];

    [self.reachability removeObserver:a];
}

- (void)testNoObservers
{
    XCTestExpectation *aExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://sentry.io"];
    [aExp setInverted:YES];
    TestSentryReachabilityObserver *a =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:aExp];
    [self.reachability addObserver:a];
    [self.reachability removeObserver:a];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    [self waitForExpectations:@[ aExp ] timeout:1.0];

    [self.reachability removeAllObservers];
}

- (void)testReportSameObserver_OnlyCalledOnce
{
    XCTestExpectation *aExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://sentry.io"];
    aExp.expectedFulfillmentCount = 1;
    TestSentryReachabilityObserver *a =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:aExp];
    [self.reachability addObserver:a];
    [self.reachability addObserver:a];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    [self waitForExpectations:@[ aExp ] timeout:1.0];

    [self.reachability removeObserver:a];
}

- (void)testReportSameReachabilityState_OnlyCalledOnce
{
    XCTestExpectation *aExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://sentry.io"];
    aExp.expectedFulfillmentCount = 1;
    TestSentryReachabilityObserver *a =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:aExp];
    [self.reachability addObserver:a];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    [self waitForExpectations:@[ aExp ] timeout:1.0];

    [self.reachability removeObserver:a];
}

@end
#endif // !TARGET_OS_WATCH
