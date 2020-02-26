//
//  SentryBreadcrumbTests.m
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryFileManager.h"
#import "NSDate+SentryExtras.h"
#import "SentryDsn.h"

@interface SentryBreadcrumbTests : XCTestCase

@property (nonatomic, strong) SentryFileManager *fileManager;

@end

@implementation SentryBreadcrumbTests

- (void)setUp {
    [super setUp];
    NSError *error = nil;
    self.fileManager = [[SentryFileManager alloc] initWithDsn:[[SentryDsn alloc] initWithString:@"https://username:password@app.getsentry.com/12345" didFailWithError:nil] didFailWithError:&error];
    XCTAssertNil(error);
}

- (void)tearDown {
    [super tearDown];
    //SentryClient.logLevel = kSentryLogLevelError;
    [self.fileManager deleteAllStoredEvents];
    [self.fileManager deleteAllFolders];
}

//- (void)testAddBreadcumb {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
//    SentryScope *scope = [SentryScope new];
//    XCTAssertNil(error);
//    [scope.breadcrumbs clear];
//    [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)1);
//}

//- (void)testBreadcumbLimit {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
//    SentryScope *scope = [SentryScope new];
//    XCTAssertNil(error);
//    [scope.breadcrumbs clear];
//    for (NSInteger i = 0; i <= 100; i++) {
//        [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    }
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)50);
//
//    [scope.breadcrumbs clear];
//    for (NSInteger i = 0; i < 49; i++) {
//        [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    }
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)49);
//    [scope.breadcrumbs serialize];
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)49);
//
//    [scope.breadcrumbs clear];
//    for (NSInteger i = 0; i < 51; i++) {
//        [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    }
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)50);
//
//    [scope.breadcrumbs clear];
//    scope.breadcrumbs.maxBreadcrumbs = 75;
//    for (NSInteger i = 0; i <= 100; i++) {
//        [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    }
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)75);
//
//    // Hard limit
//    [scope.breadcrumbs clear];
//    scope.breadcrumbs.maxBreadcrumbs = 250;
//    for (NSInteger i = 0; i <= 250; i++) {
//        [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    }
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)200);
//
//    // Extend Hard limit
//    [scope.breadcrumbs clear];
//    scope.breadcrumbs.maxBreadcrumbs = 250;
//    client.maxBreadcrumbs = 220;
//    for (NSInteger i = 0; i <= 250; i++) {
//        [scope.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
//    }
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)220);
//}

//- (void)testSerialize {
//    NSError *error = nil;
////    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
//    SentryScope *scope = [SentryScope new];
//    XCTAssertNil(error);
//    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
//    NSDate *date = [NSDate date];
//    crumb.timestamp = date;
//    crumb.data = @{@"data": date, @"dict": @{@"date": date}};
//    [scope.breadcrumbs addBreadcrumb:crumb];
//    NSDictionary *serialized = @{@"breadcrumbs": @[@{
//                                 @"category": @"http",
//                                 @"data": @{
//                                         @"data": [date sentry_toIso8601String],
//                                         @"dict": @{
//                                                 @"date": [date sentry_toIso8601String]
//                                                 }
//                                         },
//                                 @"level": @"debug",
//                                 @"timestamp": [date sentry_toIso8601String]
//                                 }]
//                                 };
//    XCTAssertEqualObjects([scope.breadcrumbs serialize], serialized);
//}

//- (void)testSerializeSorted {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
//    SentryScope *scope = [SentryScope new];
//    XCTAssertNil(error);
//    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
//    NSDate *date = [NSDate dateWithTimeIntervalSince1970:10];
//    crumb.timestamp = date;
//    [scope.breadcrumbs addBreadcrumb:crumb];
//
//    SentryBreadcrumb *crumb2 = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
//    NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:899990];
//    crumb2.timestamp = date2;
//    [scope.breadcrumbs addBreadcrumb:crumb2];
//
//    SentryBreadcrumb *crumb3 = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
//    NSDate *date3 = [NSDate dateWithTimeIntervalSince1970:5];
//    crumb3.timestamp = date3;
//    [scope.breadcrumbs addBreadcrumb:crumb3];
//
//    SentryBreadcrumb *crumb4 = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
//    NSDate *date4 = [NSDate dateWithTimeIntervalSince1970:11];
//    crumb4.timestamp = date4;
//    [scope.breadcrumbs addBreadcrumb:crumb4];
//
//    NSDictionary *serialized = [scope.breadcrumbs serialize];
//    NSArray *dates = [serialized valueForKeyPath:@"breadcrumbs.timestamp"];
//    XCTAssertTrue([[dates objectAtIndex:0] isEqualToString:[date sentry_toIso8601String]]);
//    XCTAssertTrue([[dates objectAtIndex:1] isEqualToString:[date2 sentry_toIso8601String]]);
//    XCTAssertTrue([[dates objectAtIndex:2] isEqualToString:[date3 sentry_toIso8601String]]);
//    XCTAssertTrue([[dates objectAtIndex:3] isEqualToString:[date4 sentry_toIso8601String]]);
//}

- (SentryBreadcrumb *)getBreadcrumb {
    return [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug category:@"http"];
}

@end
