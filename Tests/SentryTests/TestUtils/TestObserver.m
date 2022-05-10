#import "TestObserver.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryCrashIntegration.h"
#import "SentryCurrentDate.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryHub.h"
#import "SentryOptions.h"
#import "SentrySdk+Private.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
TestObserver ()

@property (nonatomic, strong) SentryHub *hub;

@end

@implementation TestObserver

+ (void)load
{
    NSString *value = [NSProcessInfo processInfo].environment[@"SEND_TEST_FAILURES_TO_SENTRY"];
    if (value == nil) {
        [[XCTestObservationCenter sharedTestObservationCenter]
            addTestObserver:[[TestObserver alloc] init]];
    }
}

- (void)testBundleWillStart:(NSBundle *)testBundle
{
    // The SentryCrashIntegration enriches the scope. We need to install the integration
    // once to get the scope data.
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557";
    }];

    // We create our own hub here, because we don't know the state of the SentrySDK.
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = @"https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557";
    options.environment = @"unit-tests";
    options.maxBreadcrumbs = 5000;
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];

    self.hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    [self.hub configureScope:^(SentryScope *scope) { [SentryCrashIntegration enrichScope:scope]; }];
}

- (void)testCaseWillStart:(XCTestCase *)testCase
{

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug
                                                             category:@"test.started"];
    [crumb setMessage:testCase.name];
    [crumb setTimestamp:[NSDate new]];
    [self.hub addBreadcrumb:crumb];
}

- (void)testCase:(XCTestCase *)testCase didRecordIssue:(XCTIssue *)issue
{
    // Tests set a fixed time. We want to use the current time for sending
    // the test result to Sentry.
    id<SentryCurrentDateProvider> currentDateProvider = [SentryCurrentDate getCurrentDateProvider];
    [SentryCurrentDate setCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]];

    NSException *exception = [[NSException alloc] initWithName:testCase.name
                                                        reason:[issue description]
                                                      userInfo:nil];
    [self.hub captureException:exception withScope:self.hub.scope];

    [SentryCurrentDate setCurrentDateProvider:currentDateProvider];
}

- (void)testBundleDidFinish:(NSBundle *)testBundle
{
    // Wait for events to flush out.
    [NSThread sleepForTimeInterval:3.0];
}

@end

NS_ASSUME_NONNULL_END
