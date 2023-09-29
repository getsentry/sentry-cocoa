#import "SentryReachability+Private.h"
#import "SentryReachability.h"
#import <XCTest/XCTest.h>

@interface TestSentryReachabilityObserver : NSObject <SentryReachabilityObserver>
@end
@implementation TestSentryReachabilityObserver
@end

#if !TARGET_OS_WATCH
@interface SentryConnectivityTest : XCTestCase
@property (strong, nonatomic) SentryReachability *reachability;
@end

@implementation SentryConnectivityTest

- (void)setUp
{
    self.reachability = [[SentryReachability alloc] init];
}

- (void)tearDown
{
    self.reachability = nil;
}

- (void)testConnectivityRepresentations
{
    XCTAssertEqualObjects(SentryConnectivityNone, SentryConnectivityFlagRepresentation(0));
    XCTAssertEqualObjects(SentryConnectivityNone,
        SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsDirect));
#    if UIKIT_LINKED
    // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
    XCTAssertEqualObjects(SentryConnectivityNone,
        SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN));
    XCTAssertEqualObjects(SentryConnectivityCellular,
        SentryConnectivityFlagRepresentation(
            kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable));
#    endif // UIKIT_LINKED
    XCTAssertEqualObjects(SentryConnectivityWiFi,
        SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable));
    XCTAssertEqualObjects(SentryConnectivityWiFi,
        SentryConnectivityFlagRepresentation(
            kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsDirect));
}

- (void)testMultipleReachabilityObservers
{
    SentryReachability *reachability = [[SentryReachability alloc] init];

    XCTestExpectation *aExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://sentry.io"];
    aExp.expectedFulfillmentCount = 5;
    TestSentryReachabilityObserver *a = [[TestSentryReachabilityObserver alloc] init];
    [reachability addObserver:a
                 withCallback:^(__unused BOOL connected,
                     NSString *_Nonnull __unused typeDescription) { [aExp fulfill]; }];

    SentryConnectivityCallback(reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsReachable, nil); // ignored, as it's the first callback
    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsInterventionRequired, nil);

    XCTestExpectation *bExp =
        [self expectationWithDescription:
                  @"reachability state change for observer monitoring https://google.io"];
    bExp.expectedFulfillmentCount = 2;
    TestSentryReachabilityObserver *b = [[TestSentryReachabilityObserver alloc] init];
    [reachability addObserver:b
                 withCallback:^(__unused BOOL connected,
                     NSString *_Nonnull __unused typeDescription) { [bExp fulfill]; }];

    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsInterventionRequired, nil);

    [reachability removeObserver:b];

    SentryConnectivityCallback(
        reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    [self waitForExpectationsWithTimeout:1.f handler:nil];
}

@end
#endif // !TARGET_OS_WATCH
