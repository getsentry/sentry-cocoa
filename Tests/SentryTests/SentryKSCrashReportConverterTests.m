//
//  SentryCrashReportConverterTests.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryCrashReportConverter.h"

@interface SentryCrashReportConverterTests : XCTestCase

@end

@implementation SentryCrashReportConverterTests

- (void)tearDown {
    [super tearDown];
}

//- (void)testConvertReport {
//    reportPath = @"Resources/crash-report-1";
//    NSDictionary *report = [self getCrashReport];
//
//    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:report];
//    SentryEvent *event = [reportConverter convertReportToEvent];
//    XCTAssertNotNil(event);
//    XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:@(1491210797).integerValue], event.timestamp);
//    XCTAssertEqual(event.debugMeta.count, (unsigned long)256);
//    SentryDebugMeta *firstDebugImage = event.debugMeta.firstObject;
//    XCTAssertTrue([firstDebugImage.name isEqualToString:@"/var/containers/Bundle/Application/94765405-4249-4E20-B1E7-9801C14D5645/CrashProbeiOS.app/CrashProbeiOS"]);
//    XCTAssertTrue([firstDebugImage.uuid isEqualToString:@"363F8E49-2D2A-3A26-BF90-60D6A8896CF0"]);
//    XCTAssertTrue([firstDebugImage.imageAddress isEqualToString:@"0x0000000100034000"]);
//    XCTAssertTrue([firstDebugImage.imageVmAddress isEqualToString:@"0x0000000100000000"]);
//    XCTAssertEqualObjects(firstDebugImage.imageSize, @(65536));
//    XCTAssertEqualObjects(firstDebugImage.cpuType, @(16777228));
//    XCTAssertEqualObjects(firstDebugImage.cpuSubType, @(0));
//    XCTAssertEqualObjects(firstDebugImage.majorVersion, @(0));
//    XCTAssertEqualObjects(firstDebugImage.minorVersion, @(0));
//    XCTAssertEqualObjects(firstDebugImage.revisionVersion, @(0));
//
//    SentryException *exception = event.exceptions.firstObject;
//    XCTAssertEqualObjects(exception.thread.stacktrace.frames.lastObject.symbolAddress, @"0x000000010014c1ec");
//    XCTAssertEqualObjects(exception.thread.stacktrace.frames.lastObject.instructionAddress, @"0x000000010014caa4");
//    XCTAssertEqualObjects(exception.thread.stacktrace.frames.lastObject.imageAddress, @"0x0000000100144000");
//    XCTAssertEqualObjects(exception.thread.stacktrace.registers[@"x4"], @"0x0000000102468000");
//    XCTAssertEqualObjects(exception.thread.stacktrace.registers[@"x9"], @"0x32a77e172fd70062");
//
//    XCTAssertEqualObjects(exception.thread.crashed, @(YES));
//    XCTAssertEqualObjects(exception.thread.current, @(NO));
//    XCTAssertEqualObjects(exception.thread.name, @"com.apple.main-thread");
//    XCTAssertEqual(event.threads.count, (unsigned long)10);
//
//    XCTAssertEqual(event.exceptions.count, (unsigned long)1);
//    SentryThread *firstThread = event.threads.firstObject;
//    XCTAssertEqualObjects(exception.thread.threadId, firstThread.threadId);
//    XCTAssertNil(firstThread.stacktrace);
//    NSString *code = [NSString stringWithFormat:@"%@", [exception.mechanism.meta valueForKeyPath:@"signal.code"]];
//    NSString *number = [NSString stringWithFormat:@"%@", [exception.mechanism.meta valueForKeyPath:@"signal.number"]];
//    NSString *exc = [NSString stringWithFormat:@"%@", [exception.mechanism.meta valueForKeyPath:@"mach_exception.name"]];
//    XCTAssertEqualObjects(code, @"0");
//    XCTAssertEqualObjects(number, @"10");
//    XCTAssertEqualObjects(exc, @"EXC_BAD_ACCESS");
//    XCTAssertEqualObjects([exception.mechanism.data valueForKeyPath:@"relevant_address"], @"0x0000000102468000");
//
//    XCTAssertTrue([NSJSONSerialization isValidJSONObject:[event serialize]]);
//    XCTAssertNotNil([[event serialize] valueForKeyPath:@"exception.values"]);
//    XCTAssertNotNil([[event serialize] valueForKeyPath:@"threads.values"]);
//
//    XCTAssertEqualObjects(event.releaseName, @"io.sentry.crashTest-1.4.1");
//    XCTAssertEqualObjects(event.dist, @"201702072010");
//}

- (void)testRawWithCrashReport {
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/raw-crash"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *serializedEvent = [event serialize];

    NSDictionary *eventJson = [self getCrashReport:@"Resources/converted-event"];

    NSArray *convertedDebugImages = ((NSArray *)[eventJson valueForKeyPath:@"debug_meta.images"]);
    NSArray *serializedDebugImages = ((NSArray *)[serializedEvent valueForKeyPath:@"debug_meta.images"]);
    XCTAssertEqual(convertedDebugImages.count, serializedDebugImages.count);
    for (NSUInteger i = 0; i < convertedDebugImages.count; i++) {
        [self compareDict:[convertedDebugImages objectAtIndex:i] withDict:[serializedDebugImages objectAtIndex:i]];
    }
}

//- (void)testAbort {
//    reportPath = @"Resources/Abort";
//    [self isValidReport];
//    NSDictionary *rawCrash = [self getCrashReport];
//    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
//    SentryEvent *event = [reportConverter convertReportToEvent];
//    XCTAssertEqualObjects([[event serialize] valueForKeyPath:@"contexts.os.name"], @"iOS");
//}

- (void)testMissingBinary {
    [self isValidReport:@"Resources/Crash-missing-binary-images"];
}

- (void)testMissingCrashError {
    [self isValidReport:@"Resources/Crash-missing-crash-error"];
}

- (void)testMissingThreads {
    [self isValidReport:@"Resources/Crash-missing-crash-threads"];
}

- (void)testMissingCrash {
    [self isValidReport:@"Resources/Crash-missing-crash"];
}

- (void)testMissingUser {
    [self isValidReport:@"Resources/Crash-missing-user"];
}

- (void)testNSException {
    [self isValidReport:@"Resources/NSException"];
}

- (void)testUnknownTypeException {
    [self isValidReport:@"Resources/UnknownTypeException"];
}


- (void)testStackoverflow {
    [self isValidReport:@"Resources/StackOverflow"];
}

- (void)testCPPException {
    [self isValidReport:@"Resources/CPPException"];
}

- (void)testNXPage {
    [self isValidReport:@"Resources/NX-Page"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/NX-Page"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.thread.stacktrace.frames.lastObject.function, @"<redacted>");
}

- (void)testReactNative {
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/ReactNative"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
//    Error: SentryClient: Test throw error
    XCTAssertEqualObjects(event.exceptions.firstObject.type, @"Error");
    XCTAssertEqualObjects(event.exceptions.firstObject.value, @"SentryClient: Test throw error");
    [self isValidReport:@"Resources/ReactNative"];
}

- (void)testIncomplete {
    [self isValidReport:@"Resources/incomplete"];
}

- (void)testDuplicateFrame {
    // There are 23 frames in the report but it should remove the duplicate
    [self isValidReport:@"Resources/dup-frame"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/dup-frame"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqual(exception.thread.stacktrace.frames.count, (unsigned long)22);
    XCTAssertEqualObjects(exception.value, @"-[__NSArrayI objectForKey:]: unrecognized selector sent to instance 0x1e59bc50");
}

- (void)testNewNSException {
    [self isValidReport:@"Resources/sentry-ios-cocoapods-report-0000000053800000"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/sentry-ios-cocoapods-report-0000000053800000"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.value, @"this is the reason");
}

- (void)testFatalError {
    [self isValidReport:@"Resources/fatalError"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatalError"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(event.exceptions.firstObject.value, @"crash: > fatal error > hello my crash is here");
}

- (void)testUserInfo {
    [self isValidReport:@"Resources/fatalError"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatalError"];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:rawCrash];
    reportConverter.userContext = @{@"tags": @{@"a": @"b",@"c": @"d"},
                                    @"extra": @{@"a": @"b",@"c": @"d",@"e": @"f"},
                                    @"user": @{
                                            @"email": @"john@apple.com",
                                            @"data":     @{
                                                    @"is_admin": @(NO)
                                                    },
                                            @"id": @"12341",
                                            @"username": @"username"
                                            }};
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *serializedUser = @{
                                     @"email": @"john@apple.com",
                                     @"data":     @{
                                         @"is_admin": @(NO)
                                     },
                                     @"id": @"12341",
                                     @"username": @"username"
                                     };
    [self compareDict:serializedUser withDict:[event.user serialize]];
    XCTAssertEqual(event.tags.count, (unsigned long)2);
    XCTAssertEqual(event.extra.count, (unsigned long)3);
}

#pragma mark private helper

- (void)isValidReport:(NSString *)path {
    NSDictionary *report = [self getCrashReport:path];
    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:report];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:[event serialize]]);
}

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

- (NSDictionary *)getCrashReport:(NSString *)path {
    NSString *jsonPath = [[NSBundle bundleForClass:self.class] pathForResource:path ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:jsonPath]];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

- (void)printJson:(SentryEvent *)event {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[event serialize]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];

    NSLog(@"%@", [NSString stringWithFormat:@"%@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]]);
}
//
//
//- (void)testSentryLevelFromString {
//    NSDictionary *report = [self getCrashReport];
//    SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:report];
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:nil], kSentryLevelError);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"log"], kSentryLevelInfo);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"info"], kSentryLevelInfo);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"bla"], kSentryLevelError);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"error"], kSentryLevelError);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"fatal"], kSentryLevelFatal);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"debug"], kSentryLevelDebug);
//    XCTAssertEqual([SentryJavaScriptBridgeHelper sentryLevelFromString:@"warning"], kSentryLevelWarning);
//}


@end
