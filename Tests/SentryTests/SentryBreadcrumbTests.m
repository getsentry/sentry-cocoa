//
//  SentryBreadcrumbs.m
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>

@interface SentryBreadcrumbTests : XCTestCase

@end

@implementation SentryBreadcrumbTests

- (void)testAddBreadcumb {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    XCTAssertTrue(client.breadcrumbs.breadcrumbs.count == 1);
}

- (void)testBreadcumbLimit {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    for (NSInteger i = 0; i <= 100; i++) {
        [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    }
    XCTAssertTrue(client.breadcrumbs.breadcrumbs.count == 50);
}

- (void)testClearBreadcumb {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    [client.breadcrumbs clear];
    XCTAssertTrue(client.breadcrumbs.breadcrumbs.count == 0);
}

- (SentryBreadcrumb *)getBreadcrumb {
    return [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
}

@end
