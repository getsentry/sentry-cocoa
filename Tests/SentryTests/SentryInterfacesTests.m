//
//  SentryInterfacesTests.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>

@interface SentryInterfacesTests : XCTestCase

@end

@implementation SentryInterfacesTests

- (void)testDebugMeta1 {
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] initWithUuid:@"abcd"];
    XCTAssertNotNil(debugMeta.uuid);
    NSDictionary *serialized = @{@"cpu_subtype": @(0),
                                 @"cpu_type": @(0),
                                 @"image_size": @(0),
                                 @"major_version": @(0),
                                 @"minor_version": @(0),
                                 @"revision_version": @(0),
                                 @"uuid": @"abcd"};
    XCTAssertEqualObjects(debugMeta.serialized, serialized);
    
    SentryDebugMeta *debugMeta2 = [[SentryDebugMeta alloc] initWithUuid:@"abcde"];
    debugMeta2.imageAddress = [NSString stringWithFormat:@"0x%016llx", @(4295180288).unsignedLongLongValue];
    NSDictionary *serialized2 = @{@"cpu_subtype": @(0),
                                  @"cpu_type": @(0),
                                  @"image_size": @(0),
                                  @"major_version": @(0),
                                  @"minor_version": @(0),
                                  @"revision_version": @(0),
                                  @"image_addr": @"0x0000000100034000",
                                  @"uuid": @"abcde"};
    XCTAssertEqualObjects(debugMeta2.serialized, serialized2);
}

@end
