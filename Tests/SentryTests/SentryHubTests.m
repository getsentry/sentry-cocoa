#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryHub.h"

@interface SentryHubTests : XCTestCase

@end

@implementation SentryHubTests

- (void)testBeforeBreadcrumbWithoutCallbackStoresBreadcrumb {
    SentryHub *hub = [[SentryHub alloc] init];
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
    SentryHub *hub = [[SentryHub alloc] init];
    [hub bindClient:client];

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
    [hub addBreadcrumb:crumb];
    SentryScope *scope = [hub getScope];
    id scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNil(scopeBreadcrumbs);
}

@end
