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
    
    XCTAssertEqual(event.exceptions.count, (unsigned long)1);
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.thread.threadId, firstThread.threadId);
    XCTAssertEqualObjects(exception.mechanism[@"posix_signal"][@"name"], @"SIGBUS");
    XCTAssertEqualObjects(exception.mechanism[@"mach_exception"][@"exception_name"], @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(exception.mechanism[@"relevant_address"], @"0x0000000102468000");
    
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:event.serialized]);
    XCTAssertNotNil([event.serialized valueForKeyPath:@"exception.values"]);
    XCTAssertNotNil([event.serialized valueForKeyPath:@"threads.values"]);
}

- (void)testRawWithCrashReport {
    reportPath = @"Resources/raw-crash";
    NSDictionary *rawCrash = [self getCrashReport];
    SentryKSCrashReportConverter *reportConverter = [[SentryKSCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *serializedEvent = event.serialized;
    
    reportPath = @"Resources/converted-event";
    NSDictionary *eventJson = [self getCrashReport];
    
    // If this line succeeds we are golden
    //[self compareDict:eventJson withDict:serializedEvent];
    
    NSArray *convertedDebugImages = ((NSArray *)[eventJson valueForKeyPath:@"debug_meta.images"]);
    NSArray *serializedDebugImages = ((NSArray *)[serializedEvent valueForKeyPath:@"debug_meta.images"]);
    XCTAssertEqual(convertedDebugImages.count, serializedDebugImages.count);
    for (NSUInteger i = 0; i < convertedDebugImages.count; i++) {
        [self compareDict:[convertedDebugImages objectAtIndex:i] withDict:[serializedDebugImages objectAtIndex:i]];
    }
    
    NSArray *convertedThreads = ((NSArray *)[eventJson valueForKeyPath:@"threads.values"]);
    NSArray *serializedThreads = ((NSArray *)[serializedEvent valueForKeyPath:@"threads.values"]);
    
    XCTAssertEqual(convertedThreads.count, serializedThreads.count);
    for (NSUInteger i = 0; i < convertedThreads.count; i++) {
        [self compareDict:[convertedThreads objectAtIndex:i] withDict:[serializedThreads objectAtIndex:i]];
    }
    
    NSArray *convertedStacktrace = [((NSArray *)[eventJson valueForKeyPath:@"threads.values"]).firstObject valueForKeyPath:@"stacktrace.frames"];
    NSArray *serializedStacktrace = [((NSArray *)[serializedEvent valueForKeyPath:@"threads.values"]).firstObject valueForKeyPath:@"stacktrace.frames"];
    
    XCTAssertEqual(convertedStacktrace.count, serializedStacktrace.count);
    for (NSUInteger i = 0; i < convertedStacktrace.count; i++) {
        [self compareDict:[convertedStacktrace objectAtIndex:i] withDict:[serializedStacktrace objectAtIndex:i]];
    }
}

#pragma mark private helper

- (void)compareDict:(NSDictionary *)one withDict:(NSDictionary *)two {
    XCTAssertEqual([one allKeys].count, [two allKeys].count, @"one: %@, two: %@", one, two);
    for (NSString *key in [one allKeys]) {
        if ([[one valueForKey:key] isKindOfClass:NSString.class] && [[one valueForKey:key] hasPrefix:@"0x"]) {
            unsigned long long result1;
            unsigned long long result2;
            [[NSScanner scannerWithString:[one valueForKey:key]] scanHexLongLong:&result1];
            [[NSScanner scannerWithString:[two valueForKey:key]] scanHexLongLong:&result2];
            XCTAssertEqual(result1, result2);
        } else if ([[one valueForKey:key] isKindOfClass:NSArray.class]) {
            NSArray *oneArray = [one valueForKey:key];
            NSArray *twoArray = [two valueForKey:key];
            for (NSUInteger i = 0; i < oneArray.count; i++) {
                [self compareDict:[oneArray objectAtIndex:i] withDict:[twoArray objectAtIndex:i]];
            }
        } else if ([[one valueForKey:key] isKindOfClass:NSDictionary.class]) {
            [self compareDict:[one valueForKey:key] withDict:[two valueForKey:key]];
        } else {
            XCTAssertEqualObjects([one valueForKey:key], [two valueForKey:key]);
        }
    }
}

- (NSDictionary *)getCrashReport {
    NSString *jsonPath = [[NSBundle bundleForClass:self.class] pathForResource:reportPath ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:jsonPath]];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

@end
