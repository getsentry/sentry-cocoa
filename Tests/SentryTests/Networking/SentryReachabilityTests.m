#import "SentryLog.h"
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
    NSLog(
        @"Received connectivity notification: %i; type: %s", connected, typeDescription.UTF8String);
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
    // Ignore the actual reachability callbacks, cause we call the callbacks manually.
    // Otherwise, the actual reachability callbacks are called during later unrelated tests causing
    // flakes.
    SentrySetReachabilityIgnoreActualCallback(YES);

    self.reachability = [[SentryReachability alloc] init];
    self.reachability.skipRegisteringActualCallbacks = YES;
}

- (void)tearDown
{
    [self.reachability removeAllObservers];
    self.reachability = nil;
    SentrySetReachabilityIgnoreActualCallback(NO);
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
    NSLog(@"[Sentry] [TEST] creating observer A");
    TestSentryReachabilityObserver *observerA = [[TestSentryReachabilityObserver alloc] init];
    NSLog(@"[Sentry] [TEST] adding observer A as reachability observer");
    [self.reachability addObserver:observerA];

    NSLog(@"[Sentry] [TEST] throwaway reachability callback, setting to reachable");
    SentryConnectivityCallback(
        kSCNetworkReachabilityFlagsReachable); // ignored, as it's the first callback
    NSLog(@"[Sentry] [TEST] reachability callback set to unreachable");
    SentryConnectivityCallback(0);

    NSLog(@"[Sentry] [TEST] creating observer B");
    TestSentryReachabilityObserver *observerB = [[TestSentryReachabilityObserver alloc] init];
    NSLog(@"[Sentry] [TEST] adding observer B as reachability observer");
    [self.reachability addObserver:observerB];

    NSLog(@"[Sentry] [TEST] reachability callback set back to reachable");
    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);
    NSLog(@"[Sentry] [TEST] reachability callback set back to unreachable");
    SentryConnectivityCallback(0);

    NSLog(@"[Sentry] [TEST] removing observer B as reachability observer");
    [self.reachability removeObserver:observerB];

    NSLog(@"[Sentry] [TEST] reachability callback set back to reachable");
    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);

    XCTAssertEqual(5, observerA.connectivityChangedInvocations);
    XCTAssertEqual(2, observerB.connectivityChangedInvocations);

    NSLog(@"[Sentry] [TEST] removing observer A as reachability observer");
    [self.reachability removeObserver:observerA];
}

- (void)testNoObservers
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];
    [self.reachability removeObserver:observer];

    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);

    XCTAssertEqual(0, observer.connectivityChangedInvocations);

    [self.reachability removeAllObservers];
}

- (void)testReportSameObserver_OnlyCalledOnce
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];
    [self.reachability addObserver:observer];

    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);

    XCTAssertEqual(1, observer.connectivityChangedInvocations);

    [self.reachability removeObserver:observer];
}

- (void)testReportSameReachabilityState_OnlyCalledOnce
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];

    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);
    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);
    SentryConnectivityCallback(kSCNetworkReachabilityFlagsReachable);

    XCTAssertEqual(1, observer.connectivityChangedInvocations);

    [self.reachability removeObserver:observer];
}

/**
 * We only want to make sure running the actual registering and unregistering callbacks doesn't
 * crash.
 */
- (void)testRegisteringActualCallbacks
{
    self.reachability.skipRegisteringActualCallbacks = NO;

    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];

    [self.reachability addObserver:observer];
    [self.reachability removeObserver:observer];
}

@end
#endif // !TARGET_OS_WATCH
