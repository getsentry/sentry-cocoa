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
    return [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug category:@"http"];
}

- (void)testSetExtra {
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtras:@{@"c": @"d"}];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"extra"], @{@"c": @"d"});
}

- (void)testBreadcrumbOlderReplacedByNewer {
    NSUInteger expectedMaxBreadcrumb = 1;
    SentryScope *scope = [[SentryScope alloc] initWithMaxBreadcrumbs:expectedMaxBreadcrumb];
    SentryBreadcrumb *crumb1 = [[SentryBreadcrumb alloc] init];
    [crumb1 setMessage:@"crumb 1"];
    [scope addBreadcrumb:crumb1];
    NSDictionary<NSString *, id> *scope1 = [scope serialize];
    NSArray *scope1Crumbs = [scope1 objectForKey:@"breadcrumbs"];
    XCTAssertEqual(expectedMaxBreadcrumb, [scope1Crumbs count]);

    SentryBreadcrumb *crumb2 = [[SentryBreadcrumb alloc] init];
    [crumb2 setMessage:@"crumb 2"];
    [scope addBreadcrumb:crumb2];
    NSDictionary<NSString *, id> *scope2 = [scope serialize];
    NSArray *scope2Crumbs = [scope2 objectForKey:@"breadcrumbs"];
    XCTAssertEqual(expectedMaxBreadcrumb, [scope2Crumbs count]);
}

- (void)testDefaultMaxCapacity {
    SentryScope *scope = [[SentryScope alloc] init];
    for (int i = 0; i < 2000; ++i) {
        [scope addBreadcrumb:[[SentryBreadcrumb alloc] init]];
    }

    NSDictionary<NSString *, id> *scopeSerialized = [scope serialize];
    NSArray *scopeCrumbs = [scopeSerialized objectForKey:@"breadcrumbs"];
    XCTAssertEqual(100, [scopeCrumbs count]);
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
    SentryScope *scope = [[SentryScope alloc] init];
    SentryUser *user = [[SentryUser alloc] init];
    
    [user setUserId:@"123"];
    [scope setUser:user];
    
    NSDictionary<NSString *, id> *scopeSerialized = [scope serialize];
    NSDictionary<NSString *, id> *scopeUser = [scopeSerialized objectForKey:@"user"];
    NSString *scopeUserId = [scopeUser objectForKey:@"id"];
    
    XCTAssertEqualObjects(scopeUserId, @"123");
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
    [scope setExtras:@{@"a": @"b"}];
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testInitWithScope {
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtras:@{@"a": @"b"}];
    [scope setTags:@{@"b": @"c"}];
    [scope addBreadcrumb:[self getBreadcrumb]];
    [scope setUser:[[SentryUser alloc] initWithUserId:@"id"]];
    [scope setContextValue:@{@"e": @"f"} forKey:@"myContext"];
    [scope setDist:@"456"];
    [scope setEnvironment:@"789"];
    [scope setFingerprint:@[@"a"]];
    
    NSMutableDictionary *snapshot = [scope serialize].mutableCopy;
    
    SentryScope *cloned = [[SentryScope alloc] initWithScope:scope];
    XCTAssertEqualObjects(snapshot, [cloned serialize]);
    
    [cloned setExtras:@{@"aa": @"b"}];
    [cloned setTags:@{@"ab": @"c"}];
    [cloned addBreadcrumb:[[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug category:@"http2"]];
    [cloned setUser:[[SentryUser alloc] initWithUserId:@"aid"]];
    [cloned setContextValue:@{@"ae": @"af"} forKey:@"myContext"];
    [cloned setDist:@"a456"];
    [cloned setEnvironment:@"a789"];
    
    XCTAssertEqualObjects(snapshot, [scope serialize]);
    XCTAssertNotEqualObjects([scope serialize], [cloned serialize]);
}

@end
