#import "SentryLogC.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>
@import SystemConfiguration;

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
    [SentryReachabilityTestHelper setReachabilityIgnoreActualCallback:YES];

    self.reachability = [[SentryReachability alloc] init];
    self.reachability.skipRegisteringActualCallbacks = YES;
}

- (void)tearDown
{
    [self.reachability removeAllObservers];
    self.reachability = nil;
    [SentryReachabilityTestHelper setReachabilityIgnoreActualCallback:NO];
}

- (void)testConnectivityRepresentations
{
    XCTAssertEqualObjects(
        [SentryReachabilityTestHelper stringForSentryConnectivity:SentryConnectivityNone],
        [SentryReachabilityTestHelper connectivityFlagRepresentation:0]);
    XCTAssertEqualObjects(
        [SentryReachabilityTestHelper stringForSentryConnectivity:SentryConnectivityNone],
        [SentryReachabilityTestHelper
            connectivityFlagRepresentation:kSCNetworkReachabilityFlagsIsDirect]);
#    if SENTRY_HAS_UIKIT
    // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
    XCTAssertEqualObjects(
        [SentryReachabilityTestHelper stringForSentryConnectivity:SentryConnectivityNone],
        [SentryReachabilityTestHelper
            connectivityFlagRepresentation:kSCNetworkReachabilityFlagsIsWWAN]);
    XCTAssertEqualObjects(
        [SentryReachabilityTestHelper stringForSentryConnectivity:SentryConnectivityCellular],
        [SentryReachabilityTestHelper
            connectivityFlagRepresentation:kSCNetworkReachabilityFlagsIsWWAN |
            kSCNetworkReachabilityFlagsReachable]);
#    endif // SENTRY_HAS_UIKIT
    XCTAssertEqualObjects(
        [SentryReachabilityTestHelper stringForSentryConnectivity:SentryConnectivityWiFi],
        [SentryReachabilityTestHelper
            connectivityFlagRepresentation:kSCNetworkReachabilityFlagsReachable]);
    XCTAssertEqualObjects(
        [SentryReachabilityTestHelper stringForSentryConnectivity:SentryConnectivityWiFi],
        [SentryReachabilityTestHelper
            connectivityFlagRepresentation:kSCNetworkReachabilityFlagsReachable |
            kSCNetworkReachabilityFlagsIsDirect]);
}

- (void)testMultipleReachabilityObservers
{
    NSLog(@"[Sentry] [TEST] creating observer A");
    TestSentryReachabilityObserver *observerA = [[TestSentryReachabilityObserver alloc] init];
    NSLog(@"[Sentry] [TEST] adding observer A as reachability observer");
    [self.reachability addObserver:observerA];

    NSLog(@"[Sentry] [TEST] throwaway reachability callback, setting to reachable");
    [SentryReachabilityTestHelper
        connectivityCallback:kSCNetworkReachabilityFlagsReachable]; // ignored, as it's the
                                                                    // first callback
    NSLog(@"[Sentry] [TEST] reachability callback set to unreachable");
    [SentryReachabilityTestHelper connectivityCallback:0];

    NSLog(@"[Sentry] [TEST] creating observer B");
    TestSentryReachabilityObserver *observerB = [[TestSentryReachabilityObserver alloc] init];
    NSLog(@"[Sentry] [TEST] adding observer B as reachability observer");
    [self.reachability addObserver:observerB];

    NSLog(@"[Sentry] [TEST] reachability callback set back to reachable");
    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];
    NSLog(@"[Sentry] [TEST] reachability callback set back to unreachable");
    [SentryReachabilityTestHelper connectivityCallback:0];

    NSLog(@"[Sentry] [TEST] removing observer B as reachability observer");
    [self.reachability removeObserver:observerB];

    NSLog(@"[Sentry] [TEST] reachability callback set back to reachable");
    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];

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

    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];

    XCTAssertEqual(0, observer.connectivityChangedInvocations);

    [self.reachability removeAllObservers];
}

- (void)testReportSameObserver_OnlyCalledOnce
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];
    [self.reachability addObserver:observer];

    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];

    XCTAssertEqual(1, observer.connectivityChangedInvocations);

    [self.reachability removeObserver:observer];
}

- (void)testReportSameReachabilityState_OnlyCalledOnce
{
    TestSentryReachabilityObserver *observer = [[TestSentryReachabilityObserver alloc] init];
    [self.reachability addObserver:observer];

    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];
    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];
    [SentryReachabilityTestHelper connectivityCallback:kSCNetworkReachabilityFlagsReachable];

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
