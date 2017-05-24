//
//  SentryBreadcrumbs.m
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryBreadcrumbStore.h"
#import "SentryFileManager.h"

@interface SentryBreadcrumbTests : XCTestCase

@property (nonatomic, strong) SentryFileManager *fileManager;

@end

@implementation SentryBreadcrumbTests

- (void)setUp {
    [super setUp];
    NSError *error = nil;
    self.fileManager = [[SentryFileManager alloc] initWithError:&error];
    XCTAssertNil(error);
}

- (void)tearDown {
    [super tearDown];
    SentryClient.logLevel = kSentryLogLevelError;
    [self.fileManager deleteAllStoredEvents];
    [self.fileManager deleteAllStoredBreadcrumbs];
    [self.fileManager deleteAllFolders];
}


- (void)testFailAdd {
    SentryBreadcrumbStore *breadcrumbStore = [[SentryBreadcrumbStore alloc] initWithFileManager:self.fileManager];
    [breadcrumbStore addBreadcrumb:[self getBreadcrumb]];
}

- (void)testAddBreadcumb {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs clear];
    [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)1);
}

- (void)testBreadcumbLimit {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs clear];
    for (NSInteger i = 0; i <= 100; i++) {
        [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    }
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)50);
}

- (void)testClearBreadcumb {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs clear];
    [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    [client.breadcrumbs clear];
    XCTAssertTrue(client.breadcrumbs.count == 0);
}

- (SentryBreadcrumb *)getBreadcrumb {
    return [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
}

@end
