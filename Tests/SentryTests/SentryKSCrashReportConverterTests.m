//
//  SentryKSCrashReportConverterTests.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryKSCrashReportConverter.h"

NSString *reportPath = @"";

@interface SentryKSCrashReportConverterTests : XCTestCase

@end

@implementation SentryKSCrashReportConverterTests

- (void)tearDown {
    reportPath = @"";
    [super tearDown];
}

- (void)testConvertReport {
    reportPath = @"Resources/crash-report-1";
    NSDictionary *report = [self getCrashReport];
    
    SentryKSCrashReportConverter *reportConverter = [[SentryKSCrashReportConverter alloc] initWithReport:report];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertNotNil(event);
    XCTAssertEqual(event.debugMeta.count, (unsigned long)256);
    SentryDebugMeta *firstDebugImage = event.debugMeta.firstObject;
    XCTAssertTrue([firstDebugImage.name isEqualToString:@"/var/containers/Bundle/Application/94765405-4249-4E20-B1E7-9801C14D5645/CrashProbeiOS.app/CrashProbeiOS"]);
    XCTAssertTrue([firstDebugImage.uuid isEqualToString:@"363F8E49-2D2A-3A26-BF90-60D6A8896CF0"]);
    XCTAssertTrue([firstDebugImage.imageAddress isEqualToString:@"0x0000000100034000"]);
    XCTAssertTrue([firstDebugImage.imageVmAddress isEqualToString:@"0x0000000100000000"]);
    XCTAssertEqualObjects(firstDebugImage.imageSize, @(65536));
    XCTAssertEqualObjects(firstDebugImage.cpuType, @(16777228));
    XCTAssertEqualObjects(firstDebugImage.cpuSubType, @(0));
    XCTAssertEqualObjects(firstDebugImage.majorVersion, @(0));
    XCTAssertEqualObjects(firstDebugImage.minorVersion, @(0));
    XCTAssertEqualObjects(firstDebugImage.revisionVersion, @(0));
    
    SentryThread *firstThread = event.threads.firstObject;
    XCTAssertEqualObjects(firstThread.stacktrace.frames.lastObject.symbolAddress, @"0x000000010014c1ec");
    XCTAssertEqualObjects(firstThread.stacktrace.frames.lastObject.instructionAddress, @"0x000000010014caa4");
    XCTAssertEqualObjects(firstThread.stacktrace.frames.lastObject.imageAddress, @"0x0000000100144000");
    XCTAssertEqualObjects(firstThread.stacktrace.registers[@"x4"], @"0x0000000102468000");
    XCTAssertEqualObjects(firstThread.stacktrace.registers[@"x9"], @"0x32a77e172fd70062");
    
    XCTAssertEqualObjects(firstThread.crashed, @(YES));
    XCTAssertEqualObjects(firstThread.current, @(NO));
    XCTAssertEqualObjects(firstThread.name, @"com.apple.main-thread");
    XCTAssertEqual(event.threads.count, (unsigned long)10);
}

#pragma mark private helper

- (NSDictionary *)getCrashReport {
    NSString *jsonPath = [[NSBundle bundleForClass:self.class] pathForResource:reportPath ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:jsonPath]];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

@end
