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

- (void)testValidHost
{
    XCTAssertTrue([SentryReachability isValidHostname:@"example.com"]);
    // Could be an internal network hostname
    XCTAssertTrue([SentryReachability isValidHostname:@"foo"]);

    // Definitely will not work as expected
    XCTAssertFalse([SentryReachability isValidHostname:@""]);
    XCTAssertFalse([SentryReachability isValidHostname:nil]);
    XCTAssertFalse([SentryReachability isValidHostname:@"localhost"]);
    XCTAssertFalse([SentryReachability isValidHostname:@"127.0.0.1"]);
    XCTAssertFalse([SentryReachability isValidHostname:@"::1"]);
}

- (void)mockMonitorURLWithCallback:(SentryConnectivityChangeBlock)block
{
    [SentryReachability monitorURL:[NSURL URLWithString:@""] usingCallback:block];
}

@end
