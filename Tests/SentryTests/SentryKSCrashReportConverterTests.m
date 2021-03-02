#import "NSDate+SentryExtras.h"
#import "SentryCrashReportConverter.h"
#import "SentryFrameInAppLogic.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryCrashReportConverterTests : XCTestCase

@property (nonatomic, strong) SentryFrameInAppLogic *frameInAppLogic;

@end

@implementation SentryCrashReportConverterTests

- (void)setUp
{
    [super setUp];
    self.frameInAppLogic = [[SentryFrameInAppLogic alloc] initWithInAppIncludes:@[]
                                                                  inAppExcludes:@[]];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testConvertReport
{
    NSDictionary *report = [self getCrashReport:@"Resources/crash-report-1"];

    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:report
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertNotNil(event);
    XCTAssertEqualObjects(
        [NSDate dateWithTimeIntervalSince1970:@(1491210797).integerValue], event.timestamp);
    XCTAssertEqual(event.debugMeta.count, (unsigned long)256);
    SentryDebugMeta *firstDebugImage = event.debugMeta.firstObject;
    XCTAssertTrue([firstDebugImage.name isEqualToString:@"/var/containers/Bundle/Application/"
                                                        @"94765405-4249-4E20-B1E7-9801C14D5645/"
                                                        @"CrashProbeiOS.app/CrashProbeiOS"]);
    XCTAssertTrue([firstDebugImage.uuid isEqualToString:@"363F8E49-2D2A-3A26-BF90-60D6A8896CF0"]);
    XCTAssertTrue([firstDebugImage.imageAddress isEqualToString:@"0x0000000100034000"]);
    XCTAssertTrue([firstDebugImage.imageVmAddress isEqualToString:@"0x0000000100000000"]);
    XCTAssertEqualObjects(firstDebugImage.imageSize, @(65536));

    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(
        exception.thread.stacktrace.frames.lastObject.symbolAddress, @"0x000000010014c1ec");
    XCTAssertEqualObjects(
        exception.thread.stacktrace.frames.lastObject.instructionAddress, @"0x000000010014caa4");
    XCTAssertEqualObjects(
        exception.thread.stacktrace.frames.lastObject.imageAddress, @"0x0000000100144000");
    XCTAssertEqualObjects(exception.thread.stacktrace.registers[@"x4"], @"0x0000000102468000");
    XCTAssertEqualObjects(exception.thread.stacktrace.registers[@"x9"], @"0x32a77e172fd70062");

    XCTAssertEqualObjects(exception.thread.crashed, @(YES));
    XCTAssertEqualObjects(exception.thread.current, @(NO));
    XCTAssertEqualObjects(exception.thread.name, @"com.apple.main-thread");
    XCTAssertEqual(event.threads.count, (unsigned long)9);

    XCTAssertEqual(event.exceptions.count, (unsigned long)1);
    SentryThread *firstThread = event.threads.firstObject;
    XCTAssertEqualObjects(exception.thread.threadId, firstThread.threadId);
    NSString *code = [NSString
        stringWithFormat:@"%@", [exception.mechanism.meta valueForKeyPath:@"signal.code"]];
    NSString *number = [NSString
        stringWithFormat:@"%@", [exception.mechanism.meta valueForKeyPath:@"signal.number"]];
    NSString *exc = [NSString
        stringWithFormat:@"%@", [exception.mechanism.meta valueForKeyPath:@"mach_exception.name"]];
    XCTAssertEqualObjects(code, @"0");
    XCTAssertEqualObjects(number, @"10");
    XCTAssertEqualObjects(exc, @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(
        [exception.mechanism.data valueForKeyPath:@"relevant_address"], @"0x0000000102468000");

    XCTAssertTrue([NSJSONSerialization isValidJSONObject:[event serialize]]);
    XCTAssertNotNil([[event serialize] valueForKeyPath:@"exception.values"]);
    XCTAssertNotNil([[event serialize] valueForKeyPath:@"threads.values"]);
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
        [[SentryCrashReportConverter alloc] initWithReport:report
                                           frameInAppLogic:self.frameInAppLogic];
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
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    NSDictionary *serializedEvent = [event serialize];

    NSDictionary *eventJson = [self getCrashReport:@"Resources/converted-event"];

    NSArray *convertedDebugImages = ((NSArray *)[eventJson valueForKeyPath:@"debug_meta.images"]);
    NSArray *serializedDebugImages
        = ((NSArray *)[serializedEvent valueForKeyPath:@"debug_meta.images"]);
    XCTAssertEqual(convertedDebugImages.count, serializedDebugImages.count);
    for (NSUInteger i = 0; i < convertedDebugImages.count; i++) {
        [self compareDict:[convertedDebugImages objectAtIndex:i]
                 withDict:[serializedDebugImages objectAtIndex:i]];
    }
}

- (void)testWithFaultyReport
{
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/Crash-faulty-report"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
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
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.thread.stacktrace.frames.lastObject.function, @"<redacted>");
}

- (void)testReactNative
{
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/ReactNative"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
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
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqual(exception.thread.stacktrace.frames.count, (unsigned long)22);
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
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    SentryException *exception = event.exceptions.firstObject;
    XCTAssertEqualObjects(exception.value, @"this is the reason");
}

- (void)testFatalError
{
    [self isValidReport:@"Resources/fatalError"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatalError"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(
        event.exceptions.firstObject.value, @"crash: > fatal error > hello my crash is here");
}

- (void)testUserInfo
{
    [self isValidReport:@"Resources/fatalError"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/fatalError"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
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

- (void)testBreadCrumb
{
    [self isValidReport:@"Resources/breadcrumb"];
    NSDictionary *rawCrash = [self getCrashReport:@"Resources/breadcrumb"];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:rawCrash
                                           frameInAppLogic:self.frameInAppLogic];
    SentryEvent *event = [reportConverter convertReportToEvent];
    XCTAssertEqualObjects(event.breadcrumbs.firstObject.category, @"ui.lifecycle");
    XCTAssertEqualObjects(event.breadcrumbs.firstObject.type, @"navigation");
    XCTAssertEqual(event.breadcrumbs.firstObject.level, kSentryLevelInfo);
    XCTAssertEqualObjects(
        [event.breadcrumbs.firstObject.data objectForKey:@"screen"], @"UIInputWindowController");

    NSDate *date = [NSDate sentry_fromIso8601String:@"2020-02-06T01:00:32Z"];
    XCTAssertEqual(event.breadcrumbs.firstObject.timestamp, date);
}

#pragma mark private helper

- (void)isValidReport:(NSString *)path
{
    NSDictionary *report = [self getCrashReport:path];
    SentryCrashReportConverter *reportConverter =
        [[SentryCrashReportConverter alloc] initWithReport:report
                                           frameInAppLogic:self.frameInAppLogic];
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

@end
