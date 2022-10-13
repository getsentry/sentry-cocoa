#import "SentryReachability.h"
#import <XCTest/XCTest.h>

@interface SentryConnectivityTest : XCTestCase
@end

@implementation SentryConnectivityTest

- (void)tearDown
{
    // Reset connectivity state cache
    SentryConnectivityShouldReportChange(0);
    [SentryReachability stopMonitoring];
}

- (void)testConnectivityRepresentations
{
    XCTAssertEqualObjects(@"none", SentryConnectivityFlagRepresentation(0));
    XCTAssertEqualObjects(
        @"none", SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsDirect));
#if SENTRY_HAS_UIDEVICE
    // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
    XCTAssertEqualObjects(
        @"none", SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN));
    XCTAssertEqualObjects(@"cellular",
        SentryConnectivityFlagRepresentation(
            kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable));
#endif
    XCTAssertEqualObjects(
        @"wifi", SentryConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable));
    XCTAssertEqualObjects(@"wifi",
        SentryConnectivityFlagRepresentation(
            kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsDirect));
}

- (void)mockMonitorURLWithCallback:(SentryConnectivityChangeBlock)block
{
    [SentryReachability monitorURL:[NSURL URLWithString:@""] usingCallback:block];
}

@end
