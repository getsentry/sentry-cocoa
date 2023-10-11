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
    SentryReachability *reachability = [[SentryReachability alloc] init];
    // Disable the rechability callbacks, cause we call the callbacks manually.
    // Otherwise, the rechability callbacks kick it at some point and make the tests flaky.
    reachability.setReachabilityCallback = NO;

    XCTestExpectation *aExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://sentry.io"];
    aExp.expectedFulfillmentCount = 5;
    TestSentryReachabilityObserver *a =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:aExp];
    [reachability addObserver:a];

    SentryConnectivityCallback(reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsReachable, nil); // ignored, as it's the first callback
    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsInterventionRequired, nil);

    XCTestExpectation *bExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://google.io"];
    bExp.expectedFulfillmentCount = 2;
    TestSentryReachabilityObserver *b =
        [[TestSentryReachabilityObserver alloc] initWithExpectation:bExp];
    [reachability addObserver:b];

    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsInterventionRequired, nil);

    [reachability removeObserver:b];

    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    [self waitForExpectations:@[ aExp, bExp ] timeout:1.0];

    [reachability removeObserver:a];
}

@end
#endif // !TARGET_OS_WATCH
