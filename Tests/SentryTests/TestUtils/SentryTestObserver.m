#import "SentryTestObserver.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryCurrentDate.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryHub.h"
#import "SentryLog+TestInit.h"
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

+ (void)load
{
#if defined(TESTCI)
    [[XCTestObservationCenter sharedTestObservationCenter]
        addTestObserver:[[SentryTestObserver alloc] init]];
#endif
    [SentryLog configure:YES diagnosticLevel:kSentryLevelDebug];
}

- (instancetype)init
{
    if (self = [super init]) {
        SentryOptions *options = [[SentryOptions alloc] init];
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
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

#pragma mark - XCTestObservation

- (void)testCaseWillStart:(XCTestCase *)testCase
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug
                                                             category:@"test.started"];
    [crumb setMessage:testCase.name];
    // The tests might have a different time set
    [crumb setTimestamp:[NSDate new]];
    [self.scope addBreadcrumb:crumb];
}

- (void)testBundleDidFinish:(NSBundle *)testBundle
{
    [SentrySDK flush:5.0];
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

@end

NS_ASSUME_NONNULL_END
