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
    SentryHub *hub = [self createHubWithMaxBreadcrumbs:@10];

    for (int i = 0; i <= 10; i++) {
        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
        [hub addBreadcrumb:crumb];
    }
    
    [self assertWithScopeBreadcrumbsCount:10 withHub:hub];
}

- (void)testBreadcrumbLimitThroughOptionsUsingConfigureScope {
    SentryHub *hub = [self createHubWithMaxBreadcrumbs:@10];
    
    for (int i = 0; i <= 10; i++) {
        [self addBreadcrumbThroughConfigureScope:hub];
    }
    
    [self assertWithScopeBreadcrumbsCount:10 withHub:hub];
}

- (void)testBreadcrumbCapLimit {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username@sentry.io/1",
    } didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:[[SentryScope alloc] init]];
    [hub bindClient:client];

    for (int i = 0; i <= 100; i++) {
        [self addBreadcrumbThroughConfigureScope:hub];
    }
    
    [self assertWithScopeBreadcrumbsCount:100 withHub:hub];
}

- (void)testBreadcrumbOverDefaultLimit {
    SentryHub *hub = [self createHubWithMaxBreadcrumbs:@200];

    for (int i = 0; i <= 200; i++) {
        [self addBreadcrumbThroughConfigureScope:hub];
    }
    
    [self assertWithScopeBreadcrumbsCount:200 withHub:hub];
}

- (SentryHub *) createHubWithMaxBreadcrumbs:(NSNumber *)maxBreadcrumbs {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username@sentry.io/1",
        @"maxBreadcrumbs": maxBreadcrumbs
        
    } didFailWithError: &error];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:nil];
    [hub bindClient:client];
    return hub;
}

-(void) addBreadcrumbThroughConfigureScope:(SentryHub *)hub {
    [hub configureScope:^(SentryScope * _Nonnull scope) {
        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError category:@"default"];
        [scope addBreadcrumb:crumb];
    }];
}

- (void) assertWithScopeBreadcrumbsCount:(NSUInteger)count withHub:(SentryHub *)hub {
    SentryScope *scope = [hub getScope];
    NSArray *scopeBreadcrumbs = [[scope serialize] objectForKey:@"breadcrumbs"];
    XCTAssertNotNil(scopeBreadcrumbs);
    XCTAssertEqual([scopeBreadcrumbs count], count);
}

- (void)testAddUserToTheScope {
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username@sentry.io/1"} didFailWithError: nil];
    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    SentryHub *hub = [[SentryHub alloc] initWithClient:client andScope:[[SentryScope alloc] init]];
    
    SentryUser *user = [[SentryUser alloc] init];
    [user setUserId:@"123"];
    [hub setUser:user];
    
    SentryScope *scope = [hub getScope];
    
    NSDictionary<NSString *, id> *scopeSerialized = [scope serialize];
    NSDictionary<NSString *, id> *scopeUser = [scopeSerialized objectForKey:@"user"];
    NSString *scopeUserId = [scopeUser objectForKey:@"id"];
    
    XCTAssertEqualObjects(scopeUserId, @"123");
}

@end
