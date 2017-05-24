//
//  SentryFileManagerTests.m
//  Sentry
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryFileManager.h"

@interface SentryFileManagerTests : XCTestCase

@property (nonatomic, strong) SentryFileManager *fileManager;

@end

@implementation SentryFileManagerTests

- (void)setUp {
    [super setUp];
    SentryClient.logLevel = kSentryLogLevelDebug;
    NSError *error = nil;
    self.fileManager = [[SentryFileManager alloc] initWithError:&error];
    XCTAssertNil(error);
}

- (void)tearDown {
    [super tearDown];
    SentryClient.logLevel = kSentryLogLevelError;
    [self.fileManager deleteAllStoredEvents];
    [self.fileManager deleteAllStoredBreadcrumbs];
}

- (void)testEventStoring {
    NSError *error = nil;
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityInfo];
    [self.fileManager storeEvent:event didFailWithError:&error];
    XCTAssertNil(error);
    NSArray<NSData *> *events = [self.fileManager getAllStoredEvents];
    XCTAssertTrue(events.count == 1);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:event.serialized
                                                       options:0
                                                         error:nil];
    XCTAssertEqualObjects(events.firstObject, jsonData);
}

- (void)testBreadcrumbStoring {
    NSError *error = nil;
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"category"];
    [self.fileManager storeBreadcrumb:crumb didFailWithError:&error];
    XCTAssertNil(error);
    NSArray<NSData *> *crumbs = [self.fileManager getAllStoredBreadcrumbs];
    XCTAssertTrue(crumbs.count == 1);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:crumb.serialized
                                                       options:0
                                                         error:nil];
    XCTAssertEqualObjects(crumbs.firstObject, jsonData);
}

@end
