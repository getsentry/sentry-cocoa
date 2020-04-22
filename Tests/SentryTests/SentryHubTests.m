#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryHub.h"

@interface SentryHubTests : XCTestCase

@end

@implementation SentryHubTests

- (void)testBeforeBreadcrumbWithoutCallbackStoresBreadcrumb {
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username@sentry.io/1"} didFailWithError: nil];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:[[SentryScope alloc] init]];
    // TODO: Add a better API
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
    [hub addBreadcrumb:crumb];
    SentryScope *scope = [hub getScope];
    id scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNotNil(scopeBreadcrumbs);
}

- (void)testBeforeBreadcrumbWithCallbackReturningNullDropsBreadcrumb {
    NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
    SentryBreadcrumb *(^beforeBreadcrumb)(SentryBreadcrumb *) = ^SentryBreadcrumb *(SentryBreadcrumb *crumb) {
#pragma clang diagnostic pop
        return nil;
    };
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username@sentry.io/1", @"beforeBreadcrumb": beforeBreadcrumb} didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    [hub bindClient:client];

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
    [hub addBreadcrumb:crumb];
    SentryScope *scope = [hub getScope];
    id scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNil(scopeBreadcrumbs);
}

- (void)testBreadcrumbLimitThroughOptionsUsingHubAddBreadcrumb {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username@sentry.io/1",
        @"maxBreadcrumbs": @10
        
    } didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    [hub bindClient:client];

    for (int i = 0; i <= 15; i++) {
        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
        [hub addBreadcrumb:crumb];
    }
    SentryScope *scope = [hub getScope];
    NSArray *scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNotNil(scopeBreadcrumbs);
    XCTAssertEqual([scopeBreadcrumbs count], 10);
}

- (void)testBreadcrumbLimitThroughOptionsUsingConfigureScope {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username@sentry.io/1",
        @"maxBreadcrumbs": @10
        
    } didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    [hub bindClient:client];

    
    for (int i = 0; i <= 15; i++) {
        [hub configureScope:^(SentryScope * _Nonnull scope) {
            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
            [scope addBreadcrumb:crumb];
        }];
    }
    SentryScope *scope = [hub getScope];
    NSArray *scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNotNil(scopeBreadcrumbs);
    XCTAssertEqual([scopeBreadcrumbs count], 10);
}

- (void)testBreadcrumbCapLimit {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username@sentry.io/1",
    } didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:[[SentryScope alloc] init]];
    [hub bindClient:client];

    for (int i = 0; i <= 200; i++) {
        [hub configureScope:^(SentryScope * _Nonnull scope) {
            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
            [scope addBreadcrumb:crumb];
        }];
    }
    
    SentryScope *scope = [hub getScope];
    NSArray *scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNotNil(scopeBreadcrumbs);
    XCTAssertEqual([scopeBreadcrumbs count], 100);
}

- (void)testBreadcrumbOverDefaultLimit {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username@sentry.io/1",
        @"maxBreadcrumbs": @200
    } didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    [hub bindClient:client];

    for (int i = 0; i <= 300; i++) {
        [hub configureScope:^(SentryScope * _Nonnull scope) {
            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
            [scope addBreadcrumb:crumb];
        }];
    }
    
    SentryScope *scope = [hub getScope];
    NSArray *scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNotNil(scopeBreadcrumbs);
    XCTAssertEqual([scopeBreadcrumbs count], 200);
}

@end
