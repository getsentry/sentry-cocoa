#import "SentryLog.h"
#import "SentryReachability+Private.h"
#import "SentryReachability.h"
#import <XCTest/XCTest.h>

@interface TestSentryReachabilityObserver : NSObject <SentryReachabilityObserver>

@property (assign, nonatomic) NSUInteger connectivityChangedInvocations;

@end
@implementation TestSentryReachabilityObserver

- (instancetype)init
{
    if (self = [super init]) {
        self.connectivityChangedInvocations = 0;
    }
    return self;
}

- (void)connectivityChanged:(BOOL)connected typeDescription:(nonnull NSString *)typeDescription
{
    NSLog(@"Received connectivity notification: %i; type: %@", connected, typeDescription);
    self.connectivityChangedInvocations++;
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
    [self.reachability removeAllObservers];
    self.reachability = nil;
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
    TestSentryReachabilityObserver *observerA = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observerA];

    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsReachable, nil); // ignored, as it's the first callback
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsInterventionRequired, nil);

    TestSentryReachabilityObserver *observerB = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observerB];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsInterventionRequired, nil);

    [self.reachability removeObserver:observerB];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    XCTAssertEqual(5, observerA.connectivityChangedInvocations);
    XCTAssertEqual(2, observerB.connectivityChangedInvocations);

    [self.reachability removeObserver:observerA];
}

- (void)testNoObservers
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];
    [self.reachability removeObserver:observer];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    XCTAssertEqual(0, observer.connectivityChangedInvocations);

    [self.reachability removeAllObservers];
}

- (void)testReportSameObserver_OnlyCalledOnce
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];
    [self.reachability addObserver:observer];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    XCTAssertEqual(1, observer.connectivityChangedInvocations);

    [self.reachability removeObserver:observer];
}

- (void)testReportSameReachabilityState_OnlyCalledOnce
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];

    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    XCTAssertEqual(1, observer.connectivityChangedInvocations);

    [self.reachability removeObserver:observer];
}

@end
#endif // !TARGET_OS_WATCH
