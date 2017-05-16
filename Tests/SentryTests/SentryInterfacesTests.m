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

- (void)testDebugMeta {
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] initWithUuid:@"abcd"];
    XCTAssertNotNil(debugMeta.uuid);
    NSDictionary *serialized = @{@"uuid": @"abcd"};
    XCTAssertEqualObjects(debugMeta.serialized, serialized);
    
    SentryDebugMeta *debugMeta2 = [[SentryDebugMeta alloc] initWithUuid:@"abcde"];
    debugMeta2.imageAddress = @"0x0000000100034000";
    // TODO: test all properties
    NSDictionary *serialized2 = @{@"image_addr": @"0x0000000100034000",
                                  @"uuid": @"abcde"};
    XCTAssertEqualObjects(debugMeta2.serialized, serialized2);
}

- (void)testFrame {
    SentryFrame *frame = [[SentryFrame alloc] initWithFileName:@"file://a.swift" function:@"[hey alloc]" module:@"a"];
    XCTAssertNotNil(frame.fileName);
    XCTAssertNotNil(frame.function);
    XCTAssertNotNil(frame.module);
    NSDictionary *serialized = @{@"filename": @"file://a.swift",
                                 @"function": @"[hey alloc]",
                                 @"module": @"a"};
    XCTAssertEqualObjects(frame.serialized, serialized);
    
    SentryFrame *frame2 = [[SentryFrame alloc] initWithFileName:@"file://b.swift" function:@"[hey2 alloc]" module:@"b"];
    XCTAssertNotNil(frame2.fileName);
    XCTAssertNotNil(frame2.function);
    XCTAssertNotNil(frame2.module);
    frame2.lineNumber = @(100);
    frame2.columnNumber = @(200);
    // TODO: test all properties
    NSDictionary *serialized2 = @{@"filename": @"file://b.swift",
                                  @"function": @"[hey2 alloc]",
                                  @"module": @"b",
                                  @"lineno": @(100),
                                  @"colno": @(200)};
    XCTAssertEqualObjects(frame2.serialized, serialized2);
}

@end
