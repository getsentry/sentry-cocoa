#import "SentryBreadcrumb.h"
#import "SentryCrashReportConverter.h"
#import "SentryDateUtils.h"
#import "SentryDebugMeta.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFrame.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryUser.h"
#import <XCTest/XCTest.h>
@import Sentry;

@interface SentryCrashReportConverterTests : XCTestCase

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashReportConverterTests

- (void)setUp
{
    [super setUp];
    self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testConvertReport
{
    NSDictionary *report = [self getCrashReport:@"Resources/crash-report-1"];

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:report inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertNotNil(event);
    XCTAssertEqualObjects(
        [NSDate dateWithTimeIntervalSince1970:@(1491210797).integerValue], event.timestamp);
    XCTAssertEqual(event.debugMeta.count, (unsigned long)13);
    SentryDebugMeta *firstDebugImage = event.debugMeta.firstObject;
    XCTAssertTrue([firstDebugImage.codeFile isEqualToString:@"/var/containers/Bundle/Application/"
                                                            @"94765405-4249-4E20-B1E7-9801C14D5645/"
                                                            @"CrashProbeiOS.app/CrashProbeiOS"]);
    XCTAssertTrue(
        [firstDebugImage.debugID isEqualToString:@"363F8E49-2D2A-3A26-BF90-60D6A8896CF0"]);
    XCTAssertTrue([firstDebugImage.imageAddress isEqualToString:@"0x0000000100034000"]);
    XCTAssertTrue([firstDebugImage.imageVmAddress isEqualToString:@"0x0000000100000000"]);
    XCTAssertEqualObjects(firstDebugImage.imageSize, @(65536));

    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(
        exception.stacktrace.frames.lastObject.instructionAddress, @"0x000000010014caa4");
    XCTAssertEqualObjects(
        exception.stacktrace.frames.lastObject.imageAddress, @"0x0000000100144000");
    XCTAssertEqualObjects(exception.stacktrace.registers[@"x4"], @"0x0000000102468000");
    XCTAssertEqualObjects(exception.stacktrace.registers[@"x9"], @"0x32a77e172fd70062");

    XCTAssertEqual(event.threads.count, (unsigned long)9);

    XCTAssertEqual(event.exceptions.count, (unsigned long)1);
    SentryThread *firstThread = event.threads.firstObject;
    XCTAssertEqualObjects(exception.threadId, firstThread.threadId);
    NSString *code = [NSString
        stringWithFormat:@"%@", [exception.mechanism.meta.signal valueForKeyPath:@"code"]];
    NSString *number = [NSString
        stringWithFormat:@"%@", [exception.mechanism.meta.signal valueForKeyPath:@"number"]];
    NSString *exc = [NSString
        stringWithFormat:@"%@", [exception.mechanism.meta.machException valueForKeyPath:@"name"]];

    XCTAssertEqualObjects(code, @"0");
    XCTAssertEqualObjects(number, @"10");
    XCTAssertEqualObjects(exc, @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(
        [exception.mechanism.data valueForKeyPath:@"relevant_address"], @"0x0000000102468000");
    XCTAssertNotNil(exception.mechanism.handled);
    XCTAssertFalse(exception.mechanism.handled.boolValue);

    XCTAssertTrue([NSJSONSerialization isValidJSONObject:[event serialize]]);
    XCTAssertNotNil([[event serialize] valueForKeyPath:@"exception.values"]);
    XCTAssertNotNil([[event serialize] valueForKeyPath:@"threads.values"]);

    XCTAssertEqualObjects([event.debugMeta[0].codeFile lastPathComponent], @"CrashProbeiOS");
    XCTAssertEqualObjects([event.debugMeta[1].codeFile lastPathComponent], @"CrashLibiOS");
    XCTAssertEqualObjects([event.debugMeta[2].codeFile lastPathComponent], @"KSCrash");
    XCTAssertEqualObjects(
        [event.debugMeta[3].codeFile lastPathComponent], @"libsystem_pthread.dylib");
    XCTAssertEqualObjects(
        [event.debugMeta[4].codeFile lastPathComponent], @"libsystem_kernel.dylib");
    XCTAssertEqualObjects([event.debugMeta[5].codeFile lastPathComponent], @"libdyld.dylib");
    XCTAssertEqualObjects([event.debugMeta[6].codeFile lastPathComponent], @"libsystem_c.dylib");
    XCTAssertEqualObjects([event.debugMeta[7].codeFile lastPathComponent], @"AVFAudio");
    XCTAssertEqualObjects([event.debugMeta[8].codeFile lastPathComponent], @"Foundation");
    XCTAssertEqualObjects([event.debugMeta[9].codeFile lastPathComponent], @"CoreFoundation");
    XCTAssertEqualObjects([event.debugMeta[10].codeFile lastPathComponent], @"CFNetwork");
    XCTAssertEqualObjects([event.debugMeta[11].codeFile lastPathComponent], @"GraphicsServices");
    XCTAssertEqualObjects([event.debugMeta[12].codeFile lastPathComponent], @"UIKit");
}

/**
 * Reproduces an issue for parsing a recrash report of a customer that leads to a crash.
 * The report contains a string instead of a thread dictionary in crash -> threads.
 * SentryCrashReportConverter expects threads to be a dictionary that contains the details about a
 * thread.
 */
- (void)testRecrashReport_WithThreadIsStringInsteadOfDict
{
    NSDictionary *report = [self getCrashReport:@"Resources/recrash-report"];

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:report inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    // Do only a few basic assertions here. RecrashReport is tested with testUnknownTypeException
    XCTAssertEqual(1, event.exceptions.count);
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(@"EXC_BAD_ACCESS", exception.type);
    XCTAssertEqualObjects(@"Exception 1, Code 3657279596, Subcode 8", exception.value);

    XCTAssertEqual(1, event.threads.count);
    SentryThread *thread = event.threads.firstObject;
    XCTAssertFalse(thread.crashed);
    XCTAssertFalse(thread.current);
    XCTAssertEqual(1, thread.stacktrace.frames.count);
    XCTAssertEqual(21, thread.stacktrace.registers.count);
}

- (void)testRawWithCrashReport
{
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/raw-crash"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *serializedEvent = [event serialize];

    NSDictionary *eventJson = [self getCrashReport:@"Resources/converted-event"];

    __block NSArray *serializedDebugImages
        = ((NSArray *)[serializedEvent valueForKeyPath:@"debug_meta.images"]);

    NSData *data = [NSJSONSerialization dataWithJSONObject:serializedDebugImages
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];

    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    XCTAssertNotNil(jsonString);

    NSArray *convertedDebugImages = [((NSArray *)[eventJson valueForKeyPath:@"debug_meta.images"])
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                        NSDictionary *evaluatedObject,
                                        __unused NSDictionary<NSString *, id> *bindings) {
            for (NSDictionary *image in serializedDebugImages) {
                if ([image[@"code_file"] isEqualToString:evaluatedObject[@"code_file"]])
                    return true;

                if ([image[@"debug_id"] isEqualToString:evaluatedObject[@"debug_id"]])
                    return true;
            }
            return false;
        }]];
    ;

    XCTAssertEqual(convertedDebugImages.count, serializedDebugImages.count);
    for (NSUInteger i = 0; i < serializedDebugImages.count; i++) {
        [self compareDict:[convertedDebugImages objectAtIndex:i]
                 withDict:[serializedDebugImages objectAtIndex:i]];
    }
}

- (void)testWithFaultyReport
{
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/Crash-faulty-report"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertNil(
        event, "The event should be nil, because the report conversion should have failed.");
}

- (void)testAbort
{
    [self isValidReport:@"Resources/Abort"];
}

- (void)testMissingBinary
{
    [self isValidReport:@"Resources/Crash-missing-binary-images"];
}

- (void)testMissingCrashError
{
    [self isValidReport:@"Resources/Crash-missing-crash-error"];
}

- (void)testMissingThreads
{
    [self isValidReport:@"Resources/Crash-missing-crash-threads"];
}

- (void)testMissingCrash
{
    [self isValidReport:@"Resources/Crash-missing-crash"];
}

- (void)testMissingUser
{
    [self isValidReport:@"Resources/Crash-missing-user"];
}

- (void)testNSException
{
    [self isValidReport:@"Resources/NSException"];

    NSDictionary *rawCrash = [self getCrashReport:@"Resources/NSException"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.type, @"NSInvalidArgumentException");
    XCTAssertEqualObjects(exception.value,
        @"-[__NSArrayI objectForKey:]: unrecognized selector sent to instance 0x1e59bc50");
}

- (void)testUnknownTypeException
{
    [self isValidReport:@"Resources/UnknownTypeException"];
}

- (void)testNSExceptionWithoutReason
{
    [self isValidReport:@"Resources/NSExceptionWithoutReason"];

    NSDictionary *rawCrash = [self getCrashReport:@"Resources/NSExceptionWithoutReason"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.type, @"MyCustomException");
    XCTAssertNil(exception.value);
}

- (void)testStackoverflow
{
    [self isValidReport:@"Resources/StackOverflow"];
}

- (void)testCPPException
{
    [self isValidReport:@"Resources/CPPException"];

    NSDictionary *rawCrash = [self getCrashReport:@"Resources/CPPException"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    SentryException *exception = event.exceptions.firstObject;

    XCTAssertEqualObjects(exception.value, @"MyException: Something bad happened...");
    XCTAssertEqualObjects(exception.type, @"C++ Exception");
}

- (void)testNXPage
{
    [self isValidReport:@"Resources/NX-Page"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/NX-Page"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertNil(exception.stacktrace.frames.lastObject.function);
}

- (void)testReactNative
{
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/ReactNative"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    //    Error: SentryClient: Test throw error
    XCTAssertEqualObjects(event.exceptions.firstObject.type, @"Error");
    XCTAssertEqualObjects(event.exceptions.firstObject.value, @"SentryClient: Test throw error");
    [self isValidReport:@"Resources/ReactNative"];
}

- (void)testIncomplete
{
    [self isValidReport:@"Resources/incomplete"];
}

- (void)testDuplicateFrame
{
    // There are 23 frames in the report but it should remove the duplicate
    [self isValidReport:@"Resources/dup-frame"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/dup-frame"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqual(exception.stacktrace.frames.count, (unsigned long)22);
    XCTAssertEqualObjects(exception.value,
        @"-[__NSArrayI objectForKey:]: unrecognized selector sent to instance "
        @"0x1e59bc50");
}

- (void)testNewNSException
{
    [self isValidReport:@"Resources/sentry-ios-cocoapods-report-0000000053800000"];
    NSDictionary *rawCrash =
        [self getCrashReport:@"Resources/sentry-ios-cocoapods-report-0000000053800000"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.value, @"this is the reason");
}

- (void)testFatalError
{
    [self isValidReport:@"Resources/fatal-error-notable-addresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-addresses"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(
        event.exceptions.firstObject.value, @"crash: > fatal error > hello my crash is here");
}

- (void)testFatalErrorBinaryiPhone
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-iphone"
                 expectedValue:@"iOS_Swift/ViewController.swift:53: FatalX error: Hello fatal\n"];
}

- (void)testFatalErrorBinaryMac
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-mac"
                 expectedValue:@"macOS_Swift/ViewController.swift:14: Assertion failed: hello\n"];
}

- (void)testFatalErrorBinarySimulator
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-simulator"
                 expectedValue:@"iOS_Swift/ViewController.swift:53: FatalX error: Hello fatal\n"];
}

- (void)testFatalErrorBinaryMessage2
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-message2"
                 expectedValue:@"iOS_Swift/ViewController.swift:53: FatalX error: Hello fatal\n"];
}

- (void)testFatalErrorBinary:(NSString *)reportPath expectedValue:(NSString *)expectedValue
{
    [self isValidReport:reportPath];
    NSDictionary *rawCrash = [self getCrashReport:reportPath];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(event.exceptions.firstObject.value, expectedValue);
}

- (void)testUserInfo
{
    [self isValidReport:@"Resources/fatal-error-notable-addresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-addresses"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    reportConverter.userContext = @{
        @"tags" : @ { @"a" : @"b", @"c" : @"d" },
        @"extra" : @ { @"a" : @"b", @"c" : @"d", @"e" : @"f" },
        @"user" : @ {
            @"email" : @"john@apple.com",
            @"data" : @ { @"is_admin" : @(NO) },
            @"id" : @"12341",
            @"username" : @"username"
        }
    };
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *serializedUser = @{
        @"email" : @"john@apple.com",
        @"data" : @ { @"is_admin" : @(NO) },
        @"id" : @"12341",
        @"username" : @"username"
    };
    [self compareDict:serializedUser withDict:[event.user serialize]];
    XCTAssertEqual(event.tags.count, (unsigned long)2);
    XCTAssertEqual(event.extra.count, (unsigned long)3);
}

- (void)testTraceContext
{
    [self isValidReport:@"Resources/fatal-error-notable-addresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-addresses"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    reportConverter.userContext = @{
        @"context" : @ { @"some" : @"context" },
        @"traceContext" : @ { @"trace_id" : @"1234567890", @"span_id" : @"1234567890" }
    };
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *expectedContext = @{
        @"some" : @"context",
        @"trace" : @ { @"trace_id" : @"1234567890", @"span_id" : @"1234567890" },
        @"app" : @ { @"in_foreground" : @(YES), @"is_active" : @(NO) }
    };
    [self compareDict:expectedContext withDict:event.context];
    XCTAssertNil(event.context[@"traceContext"]);
}

- (void)testAppContextInForegroundTrue_IsTrue
{
    [self isValidReport:@"Resources/fatal-error-notable-addresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-addresses"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *expectedContext =
        @{ @"app" : @ { @"in_foreground" : @(YES), @"is_active" : @(NO) } };
    [self compareDict:expectedContext withDict:event.context];
}

- (void)testAppContextInForegroundFalse_IsFalse
{
    NSMutableDictionary *rawCrash =
        [self getCrashReport:@"Resources/fatal-error-binary-images-simulator"].mutableCopy;

    NSMutableDictionary *systemDict =
        [[NSMutableDictionary alloc] initWithDictionary:rawCrash[@"system"]];
    NSMutableDictionary *applicationStats =
        [[NSMutableDictionary alloc] initWithDictionary:systemDict[@"application_stats"]];
    applicationStats[@"application_in_foreground"] = @(NO);
    systemDict[@"application_stats"] = applicationStats;
    rawCrash[@"system"] = systemDict;

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertEqual(event.context[@"app"][@"in_foreground"], @(NO));
}

- (void)testAppContextInForegroundNil_IsNil
{
    [self isValidReport:@"Resources/fatal-error-binary-images-simulator"];
    NSMutableDictionary *rawCrash =
        [self getCrashReport:@"Resources/fatal-error-binary-images-simulator"].mutableCopy;

    NSMutableDictionary *systemDict =
        [[NSMutableDictionary alloc] initWithDictionary:rawCrash[@"system"]];
    NSMutableDictionary *applicationStats =
        [[NSMutableDictionary alloc] initWithDictionary:systemDict[@"application_stats"]];
    applicationStats[@"application_in_foreground"] = nil;
    systemDict[@"application_stats"] = applicationStats;
    rawCrash[@"system"] = systemDict;

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertNil(event.context[@"app"][@"in_foreground"]);
}

- (void)testAppContextIsActiveTrue_IsTrue
{
    [self isValidReport:@"Resources/fatal-error-binary-images-simulator"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-binary-images-simulator"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertEqual(event.context[@"app"][@"is_active"], @(YES));
    XCTAssertEqual(event.context[@"app"][@"in_foreground"], @(YES));
}

- (void)testAppContextIsActiveFalse_FromCrashReport
{
    [self isValidReport:@"Resources/fatal-error-notable-addresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-addresses"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertEqual(event.context[@"app"][@"is_active"], @(NO));
    XCTAssertEqual(event.context[@"app"][@"in_foreground"], @(YES));
}

- (void)testAppContextIsActiveFalse_IsFalse
{
    NSMutableDictionary *rawCrash =
        [self getCrashReport:@"Resources/fatal-error-binary-images-simulator"].mutableCopy;

    NSMutableDictionary *systemDict =
        [[NSMutableDictionary alloc] initWithDictionary:rawCrash[@"system"]];
    NSMutableDictionary *applicationStats =
        [[NSMutableDictionary alloc] initWithDictionary:systemDict[@"application_stats"]];
    applicationStats[@"application_active"] = @(NO);
    systemDict[@"application_stats"] = applicationStats;
    rawCrash[@"system"] = systemDict;

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertEqual(event.context[@"app"][@"is_active"], @(NO));
}

- (void)testAppContextIsActiveNil_IsNil
{
    [self isValidReport:@"Resources/fatal-error-binary-images-simulator"];
    NSMutableDictionary *rawCrash =
        [self getCrashReport:@"Resources/fatal-error-binary-images-simulator"].mutableCopy;

    NSMutableDictionary *systemDict =
        [[NSMutableDictionary alloc] initWithDictionary:rawCrash[@"system"]];
    NSMutableDictionary *applicationStats =
        [[NSMutableDictionary alloc] initWithDictionary:systemDict[@"application_stats"]];
    applicationStats[@"application_active"] = nil;
    systemDict[@"application_stats"] = applicationStats;
    rawCrash[@"system"] = systemDict;

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];

    SentryEvent *event = [reportConverter convertReportToEvent];

    XCTAssertNil(event.context[@"app"][@"is_active"]);
}

/**
 * Uses two valid crash reports taken from a simulator, with matching scope data.
 */
- (void)testScopeSync_V1_VS_V2
{
    [self isValidReport:@"Resources/crash-report-user-info-scope-v1"];
    [self isValidReport:@"Resources/crash-report-user-info-scope-v2"];

    NSDictionary *rawCrashV1 = [self getCrashReport:@"Resources/crash-report-user-info-scope-v1"];
    NSDictionary *rawCrashV2 = [self getCrashReport:@"Resources/crash-report-user-info-scope-v2"];

    SentryCrashReportConverter *reportConverterV1 =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrashV1 inAppLogic:self.inAppLogic];

    SentryCrashReportConverter *reportConverterV2 =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrashV2 inAppLogic:self.inAppLogic];

    [self compareDict:reportConverterV1.userContext withDict:reportConverterV2.userContext];
}

- (void)testBreadcrumb_FromUserInfo
{
    [self testBreadcrumb:@"Resources/breadcrumb"];
}

- (void)testBreadcrumb_FromSDKScope
{
    [self testBreadcrumb:@"Resources/breadcrumb_sdk_scope"];
}

#pragma mark private helper

- (void)isValidReport:(NSString *)path
{
    NSDictionary *report = [self getCrashReport:path];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:report inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:[event serialize]]);
}

- (void)compareDict:(NSDictionary *)one withDict:(NSDictionary *)two
{
    XCTAssertEqual([one allKeys].count, [two allKeys].count, @"one: %@, two: %@", one, two);
    for (NSString *key in [one allKeys]) {
        if ([[one valueForKey:key] isKindOfClass:NSString.class] &&
            [[one valueForKey:key] hasPrefix:@"0x"]) {
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

- (NSDictionary *)getCrashReport:(NSString *)path
{
    NSString *jsonPath = [[NSBundle bundleForClass:self.class] pathForResource:path ofType:@"json"];
    if (jsonPath == nil) {
        XCTFail(@"Was unable to find crash report in resources for path: '%@'", path);
        return @{};
    }
    NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:jsonPath]];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

- (void)printJson:(SentryEvent *)event
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[event serialize]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];

    NSLog(@"%@",
        [NSString stringWithFormat:@"%@",
            [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]]);
}

- (void)testBreadcrumb:(NSString *)reportPath
{
    [self isValidReport:reportPath];
    NSDictionary *rawCrash = [self getCrashReport:reportPath];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(event.breadcrumbs.firstObject.category, @"ui.lifecycle");
    XCTAssertEqualObjects(event.breadcrumbs.firstObject.type, @"navigation");
    XCTAssertEqual(event.breadcrumbs.firstObject.level, kSentryLevelInfo);
    XCTAssertEqualObjects(
        [event.breadcrumbs.firstObject.data objectForKey:@"screen"], @"UIInputWindowController");

    NSDate *date = sentry_fromIso8601String(@"2020-02-06T01:00:32Z");
    XCTAssertEqual(event.breadcrumbs.firstObject.timestamp, date);
}

- (void)testBreadcrumbWithNilCategory_ShouldFallbackToDefaultCategory
{
    // -- Arrange --
    // Create a crash report with a breadcrumb that has nil category
    // This tests the null handling: if (!storedCrumb[@"category"]) { continue; }
    NSDictionary *mockReport = @{
        @"user" : @ {
            @"breadcrumbs" : @[
                @{
                    // Missing category key should cause breadcrumb to fallback to default category
                    @"message" : @"test message",
                    @"timestamp" : @"2020-02-06T01:00:32Z"
                },
                @{
                    @"category" : @"valid_category", // valid breadcrumb should be included
                    @"message" : @"valid message",
                    @"timestamp" : @"2020-02-06T01:00:33Z"
                }
            ]
        },
        @"crash" : @ { @"threads" : @[], @"error" : @ { @"type" : @"signal" } },
        @"binary_images" : @[],
        @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
    };

    // -- Act --
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:mockReport inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    // -- Assert --
    XCTAssertEqual(event.breadcrumbs.count, 2);
    XCTAssertEqualObjects(event.breadcrumbs.firstObject.category, @"default");
    XCTAssertEqualObjects(event.breadcrumbs.firstObject.message, @"test message");
    XCTAssertEqualObjects(
        event.breadcrumbs.firstObject.timestamp, sentry_fromIso8601String(@"2020-02-06T01:00:32Z"));

    XCTAssertEqualObjects(event.breadcrumbs.lastObject.category, @"valid_category");
    XCTAssertEqualObjects(event.breadcrumbs.lastObject.message, @"valid message");
    XCTAssertEqualObjects(
        event.breadcrumbs.lastObject.timestamp, sentry_fromIso8601String(@"2020-02-06T01:00:33Z"));
}

- (void)testThreadWithNonNumberIndex_ShouldReturnNil
{
    // -- Arrange --
    // Test with string index - should be rejected and logged
    NSDictionary *mockReportStringIndex = @{
        @"crash" : @ {
            @"threads" : @[ @{
                @"index" : @"invalid_string", // non-NSNumber index should cause thread to be nil
                @"crashed" : @NO,
                @"current_thread" : @NO,
                @"backtrace" : @ { @"contents" : @[] }
            } ],
            @"error" : @ { @"type" : @"signal" }
        },
        @"binary_images" : @[],
        @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
    };

    // -- Act --
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:mockReportStringIndex
                                                inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    // -- Assert --
    // Should have no threads since the thread with string index gets filtered out
    XCTAssertEqual(event.threads.count, 0);
}

- (void)testThreadWithNilIndex_ShouldBeAllowed
{
    // -- Arrange --
    // Test with missing index - should be allowed (for recrash reports)
    NSDictionary *mockReportNilIndex = @{
        @"crash" : @ {
            @"threads" : @[ @{
                // Missing index key should be allowed
                @"crashed" : @NO,
                @"current_thread" : @NO,
                @"backtrace" : @ {
                    @"contents" : @[ @{
                        @"instruction_addr" : @0x1000,
                        @"symbol_addr" : @0x1000,
                    } ]
                }
            } ],
            @"error" : @ { @"type" : @"signal" }
        },
        @"binary_images" : @[],
        @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
    };

    // -- Act --
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:mockReportNilIndex
                                                inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    // -- Assert --
    // Should have 1 thread since missing index is now allowed (for recrash reports)
    XCTAssertEqual(event.threads.count, 1);
    XCTAssertNil(event.threads.firstObject.threadId);
    XCTAssertEqual(event.threads.firstObject.isMain.boolValue, NO);
}

- (void)testThreadWithInvalidIndexTypes_ShouldReturnNil
{
    // Test various invalid index types
    NSArray *invalidIndexes = @[
        @{ @"some" : @"dictionary" }, // Dictionary
        @[ @"array" ], // Array
        [NSDate date], // Date
        [NSNull null] // NSNull
    ];

    for (id invalidIndex in invalidIndexes) {
        // -- Arrange --
        NSDictionary *mockReport = @{
            @"crash" : @ {
                @"threads" : @[ @{
                    @"index" : invalidIndex,
                    @"crashed" : @NO,
                    @"current_thread" : @NO,
                    @"backtrace" : @ { @"contents" : @[] }
                } ],
                @"error" : @ { @"type" : @"signal" }
            },
            @"binary_images" : @[],
            @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
        };

        // -- Act --
        SentryCrashReportConverter *reportConverter =
            [[SentryCrashReportConverter alloc] initWithReport:mockReport
                                                    inAppLogic:self.inAppLogic];
        SentryEvent *event = [reportConverter convertReportToEvent];

        // -- Assert --
        XCTAssertEqual(event.threads.count, 0,
            @"Thread with invalid index type %@ should be filtered out", [invalidIndex class]);
    }
}

- (void)testNotableAddressesWithNilValue_ShouldBeSkipped
{
    // -- Arrange --
    // Create a crash report with notable addresses where some values are nil
    // This tests the null handling: SENTRY_UNWRAP_NULLABLE(NSString, content[@"value"])
    NSDictionary *mockReport = @{
        @"crash" : @ {
            @"threads" : @[ @{
                @"index" : @0,
                @"crashed" : @YES,
                @"current_thread" : @YES,
                @"backtrace" : @ { @"contents" : @[] },
                @"notable_addresses" : @ {
                    @"address1" : @ {
                        @"type" : @"string"
                        // Missing value key should be skipped
                    },
                    @"address2" : @ {
                        @"type" : @"string",
                        @"value" : @"valid_reason" // valid value should be included
                    },
                    @"address3" : @ {
                        @"type" : @"other", // non-string type should be skipped
                        @"value" : @"should_be_ignored"
                    }
                }
            } ],
            @"error" : @ { @"type" : @"signal" }
        },
        @"binary_images" : @[],
        @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
    };

    // -- Act --
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:mockReport inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];

    // -- Assert --
    // Should not crash when notable address values are nil
    // Exception value should only contain the valid notable address value
    XCTAssertNotNil(event);
    XCTAssertEqual(event.exceptions.count, 1);
    // The null handling ensures only valid string values are processed
}

@end
