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
#import <XCTest/XCTIssue.h>
#import <XCTest/XCTest.h>
#import <XCTest/XCTestCase.h>
#import "SentryScope.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface
TestObserver ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryScope *scope;

@end

@implementation TestObserver

+ (void)load
{
    NSString *value = [NSProcessInfo processInfo].environment[@"SEND_TEST_FAILURES_TO_SENTRY"];
    if (value != nil) {
        [[XCTestObservationCenter sharedTestObservationCenter]
            addTestObserver:[[TestObserver alloc] init]];
    }
}

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
        [SentryCrashIntegration enrichScope:self.scope];
        
        self.options = options;
    }
    return self;
}

- (void)testCaseWillStart:(XCTestCase *)testCase
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug
                                                             category:@"test.started"];
    [crumb setMessage:testCase.name];
    [crumb setTimestamp:[NSDate new]];
    [self.scope addBreadcrumb:crumb];
}

- (void)testCase:(XCTestCase *)testCase didRecordIssue:(XCTIssue *)issue
{
    NSLog(@"TestObserver: DidRecordIssue");
    // Tests set a fixed time. We want to use the current time for sending
    // the test result to Sentry.
    id<SentryCurrentDateProvider> currentDateProvider = [SentryCurrentDate getCurrentDateProvider];
    [SentryCurrentDate setCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]];
    
    SentryClient *client = [[SentryClient alloc] initWithOptions:self.options];
    // We create our own hub here, because we don't know the state of the SentrySDK.
    SentryHub * hub = [[SentryHub alloc] initWithClient:client andScope:self.scope];
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
