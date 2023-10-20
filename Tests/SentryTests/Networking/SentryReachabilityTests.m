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
    printf("Received connectivity notification: %i; type: %s\n", connected,
        typeDescription.UTF8String);
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
    printf("[Sentry] [TEST] creating observer A\n");
    TestSentryReachabilityObserver *observerA = [[TestSentryReachabilityObserver alloc] init];
    printf("[Sentry] [TEST] adding observer A as reachability observer\n");
    [self.reachability addObserver:observerA];

    printf("[Sentry] [TEST] throwaway reachability callback, setting to reachable\n");
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsReachable, nil); // ignored, as it's the first callback
    printf("[Sentry] [TEST] reachability callback to set to intervention required\n");
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsInterventionRequired, nil);

    printf("[Sentry] [TEST] creating observer B\n");
    TestSentryReachabilityObserver *observerB = [[TestSentryReachabilityObserver alloc] init];
    printf("[Sentry] [TEST] adding observer B as reachability observer\n");
    [self.reachability addObserver:observerB];

    printf("[Sentry] [TEST] reachability callback to set to back to reachable\n");
    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);
    printf("[Sentry] [TEST] reachability callback to set to back to intervention required\n");
    SentryConnectivityCallback(self.reachability.sentry_reachability_ref,
        kSCNetworkReachabilityFlagsInterventionRequired, nil);

    printf("[Sentry] [TEST] removing observer B as reachability observer\n");
    [self.reachability removeObserver:observerB];

    printf("[Sentry] [TEST] reachability callback to set to back to reachable\n");
    SentryConnectivityCallback(
        self.reachability.sentry_reachability_ref, kSCNetworkReachabilityFlagsReachable, nil);

    XCTAssertEqual(5, observerA.connectivityChangedInvocations);
    XCTAssertEqual(2, observerB.connectivityChangedInvocations);

    printf("[Sentry] [TEST] removing observer A as reachability observer\n");
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
