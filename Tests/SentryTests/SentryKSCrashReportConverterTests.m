#import "NSDate+SentryExtras.h"
#import "SentryCrashReportConverter.h"
#import "SentryInAppLogic.h"
#import "SentryMechanismMeta.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryCrashReportConverterTests : XCTestCase

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashReportConverterTests

- (void)setUp
{
    [super setUp];
    self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[] inAppExcludes:@[]];
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
        exception.stacktrace.frames.lastObject.symbolAddress, @"0x000000010014c1ec");
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
}

- (void)testUnknownTypeException
{
    [self isValidReport:@"Resources/UnknownTypeException"];
}

- (void)testStackoverflow
{
    [self isValidReport:@"Resources/StackOverflow"];
}

- (void)testCPPException
{
    [self isValidReport:@"Resources/CPPException"];
}

- (void)testNXPage
{
    [self isValidReport:@"Resources/NX-Page"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/NX-Page"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.stacktrace.frames.lastObject.function, @"<redacted>");
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
    [self isValidReport:@"Resources/fatal-error-notable-adresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-adresses"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash inAppLogic:self.inAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(
        event.exceptions.firstObject.value, @"crash: > fatal error > hello my crash is here");
}

- (void)testFatalErrorBinaryiPhone
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-iphone"
                 expectedValue:@"iOS_Swift/ViewController.swift:53: Fatal error: Hello fatal\n"];
}

- (void)testFatalErrorBinaryMac
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-mac"
                 expectedValue:@"macOS_Swift/ViewController.swift:14: Assertion failed: hello\n"];
}

- (void)testFatalErrorBinarySimulator
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-simulator"
                 expectedValue:@"iOS_Swift/ViewController.swift:53: Fatal error: Hello fatal\n"];
}

- (void)testFatalErrorBinaryMessage2
{
    [self testFatalErrorBinary:@"Resources/fatal-error-binary-images-message2"
                 expectedValue:@"iOS_Swift/ViewController.swift:53: Fatal error: Hello fatal\n"];
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
    [self isValidReport:@"Resources/fatal-error-notable-adresses"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatal-error-notable-adresses"];
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

    NSDate *date = [NSDate sentry_fromIso8601String:@"2020-02-06T01:00:32Z"];
    XCTAssertEqual(event.breadcrumbs.firstObject.timestamp, date);
}

@end
