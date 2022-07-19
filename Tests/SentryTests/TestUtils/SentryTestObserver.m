#import "SentryTestObserver.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryCurrentDate.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryHub.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentrySdk+Private.h"
#import "XCTest/XCTIssue.h"
#import "XCTest/XCTest.h"
#import "XCTest/XCTestCase.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTestObserver ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryScope *scope;

@end

@implementation SentryTestObserver

#if TESTCI
+ (void)load
{
    [[XCTestObservationCenter sharedTestObservationCenter]
        addTestObserver:[[SentryTestObserver alloc] init]];
}
#endif

- (instancetype)init
{
    if (self = [super init]) {
        SentryOptions *options = [[SentryOptions alloc] init];
        options.dsn = @"https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557";
        options.environment = @"unit-tests";
        options.debug = YES;
        options.enableAutoSessionTracking = NO;
        options.maxBreadcrumbs = 5000;

        // The SentryCrashIntegration enriches the scope. We need to install the integration
        // once to get the scope data.
        [SentrySDK startWithOptionsObject:options];

        self.scope = [[SentryScope alloc] init];
        [SentryCrashIntegration enrichScope:self.scope
                               crashWrapper:[SentryCrashWrapper sharedInstance]];

        self.options = options;
    }
    return self;
}

- (void)testCaseWillStart:(XCTestCase *)testCase
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug
                                                             category:@"test.started"];
    [crumb setMessage:testCase.name];
    // The tests might have a different time set
    [crumb setTimestamp:[NSDate new]];
    [self.scope addBreadcrumb:crumb];
}

- (void)testCase:(XCTestCase *)testCase didRecordIssue:(XCTIssue *)issue
{
    // Tests set a fixed time. We want to use the current time for sending
    // the test result to Sentry.
    id<SentryCurrentDateProvider> currentDateProvider = [SentryCurrentDate getCurrentDateProvider];
    [SentryCurrentDate setCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]];

    // The tests might mess up the files or something else. Therefore, we create a fresh client and
    // hub to make sure the sending works.
    SentryClient *client = [[SentryClient alloc] initWithOptions:self.options];
    // We create our own hub here, because we don't know the state of the SentrySDK.
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:self.scope];
    NSException *exception = [[NSException alloc] initWithName:testCase.name
                                                        reason:issue.description
                                                      userInfo:nil];
    [hub captureException:exception withScope:hub.scope];

    [SentryCurrentDate setCurrentDateProvider:currentDateProvider];
}

- (void)testBundleDidFinish:(NSBundle *)testBundle
{
    // Wait for events to flush out.
    [NSThread sleepForTimeInterval:3.0];
}

@end

NS_ASSUME_NONNULL_END
