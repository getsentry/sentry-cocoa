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

- (void)testClearBreadcrumb {
    SentryScope *scope = [[SentryScope alloc] init];
    [scope clearBreadcrumbs];
    [scope addBreadcrumb:[self getBreadcrumb]];
    [scope clearBreadcrumbs];
    XCTAssertTrue([[[scope serialize] objectForKey:@"breadcrumbs"] count] == 0);
}


@end
