//
//  SentryCrashIOKit_Tests.m
//  Sentry
//
//  Created by Jamie Bishop on 07/05/2021.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "SentryCrashIOKit.h"
#import "SentryCrashSysCtl.h"

@interface SentryCrashIOKit_Tests : XCTestCase
@end

@implementation SentryCrashIOKit_Tests

- (void)testGetMacAddress
{
    unsigned char macAddress[6] = { 0 };
    bool success = sentrycrashiokit_getPrimaryInterfaceMacAddress((char *)macAddress);
    XCTAssertTrue(success, @"");
    unsigned int result = 0;
    for (unsigned i = 0; i < sizeof(macAddress); i++) {
        result |= macAddress[i];
    }
    XCTAssertTrue(result != 0, @"");
}

@end
