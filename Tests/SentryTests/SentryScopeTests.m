//
//  SentryScopeTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 25.02.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SentryBreadcrumb.h"
#import "SentryScope.h"
#import "SentryUser.h"
#import "SentryScope+Private.h"

@interface SentryScopeTests : XCTestCase

@end

@implementation SentryScopeTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (SentryBreadcrumb *)getBreadcrumb {
    return [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http"];
}

- (void)testSetExtra {
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtra:@{@"c": @"d"}];
    [scope setExtra:@{@"a": @"b"}];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"extra"], @{@"a": @"b"});
}

- (void)testSetExtraValueForKey {
    #warning TODO implement
}

- (void)testSetTags {
    #warning TODO implement
}

- (void)testSetTagValueForKey {
    #warning TODO implement
}

- (void)testSetUser {
    #warning TODO implement
}

- (void)testSerialize {
    #warning TODO implement
}

- (void)testAddBreadcrumb {
    #warning TODO implement
}

- (void)testApplyToEvent {
    #warning TODO implement
}

- (void)testSetContextValueForKey {
    #warning TODO implement
}

- (void)testCallingEventProcessors {
    #warning TODO implement
}

- (void)testClear {
    #warning TODO implement
}

- (void)testReleaseSerializes {
    SentryScope *scope = [[SentryScope alloc] init];
    NSString *expectedReleaseName = @"io.sentry.cocoa@5.0.0-deadbeef";
    [scope setReleaseName:expectedReleaseName];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"release"], expectedReleaseName);
}

- (void)testDistSerializes {
    SentryScope *scope = [[SentryScope alloc] init];
    NSString *expectedDist = @"dist-1.0";
    [scope setDist:expectedDist];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"dist"], expectedDist);
}

- (void)testEnvironmentSerializes {
    SentryScope *scope = [[SentryScope alloc] init];
    NSString *expectedEnvironment = @"production";
    [scope setEnvironment:expectedEnvironment];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"environment"], expectedEnvironment);
}

- (void)testClearBreadcrumb {
    SentryScope *scope = [[SentryScope alloc] init];
    [scope clearBreadcrumbs];
    [scope addBreadcrumb:[self getBreadcrumb]];
    [scope clearBreadcrumbs];
    XCTAssertTrue([[[scope serialize] objectForKey:@"breadcrumbs"] count] == 0);
}

- (void)testListeners {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Should call scope listener"];
    SentryScope *scope = [[SentryScope alloc] init];
    [scope addScopeListener:^(SentryScope * _Nonnull scope) {
        XCTAssertEqualObjects([[scope serialize] objectForKey:@"extra"], @{@"a": @"b"});
        [expectation fulfill];
    }];
    [scope setExtra:@{@"a": @"b"}];
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testInitWithScope {
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtra:@{@"a": @"b"}];
    [scope setTags:@{@"b": @"c"}];
    [scope addBreadcrumb:[self getBreadcrumb]];
    [scope setUser:[[SentryUser alloc] initWithUserId:@"id"]];
    [scope setContextValue:@{@"e": @"f"} forKey:@"myContext"];
    [scope setReleaseName:@"123"];
    [scope setDist:@"456"];
    [scope setEnvironment:@"789"];
    
    NSMutableDictionary *snapshot = [scope serialize].mutableCopy;
    
    SentryScope *cloned = [[SentryScope alloc] initWithScope:scope];
    XCTAssertEqualObjects(snapshot, [cloned serialize]);
    
    [cloned setExtra:@{@"aa": @"b"}];
    [cloned setTags:@{@"ab": @"c"}];
    [cloned addBreadcrumb:[[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityDebug category:@"http2"]];
    [cloned setUser:[[SentryUser alloc] initWithUserId:@"aid"]];
    [cloned setContextValue:@{@"ae": @"af"} forKey:@"myContext"];
    [cloned setReleaseName:@"a123"];
    [cloned setDist:@"a456"];
    [cloned setEnvironment:@"a789"];
    
    XCTAssertEqualObjects(snapshot, [scope serialize]);
    XCTAssertNotEqualObjects([scope serialize], [cloned serialize]);
}

@end
