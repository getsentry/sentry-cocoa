// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReportStore_Tests.m
//
//  Created by Karl Stenerud on 2012-02-05.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#if !SDK_V10
#    import "FileBasedTestCase.h"
#    import "XCTestCase+SentryCrash.h"

@import SentryTestUtilsObjC;

#    include <inttypes.h>
#    include <stdlib.h>
#    include <string.h>
#    include <time.h>

#    define REPORT_PREFIX @"CrashReport-SentryCrashTest"

typedef struct {
    char path[SentryCrashCRS_MAX_PATH_LENGTH];
    unsigned char canary[16];
} GuardedSentryCrashCRSPathBuffer;

static void
fillReportStoreCanary(GuardedSentryCrashCRSPathBuffer *buffer)
{
    memset(buffer, 0, sizeof(*buffer));
    memset(buffer->canary, 0xa5, sizeof(buffer->canary));
}

static bool
isReportStoreCanaryIntact(const GuardedSentryCrashCRSPathBuffer *buffer)
{
    for (size_t i = 0; i < sizeof(buffer->canary); i++) {
        if (buffer->canary[i] != 0xa5) {
            return false;
        }
    }
    return true;
}

static bool
isLeapYear(int year)
{
    return ((year % 4) == 0 && (year % 100) != 0) || (year % 400) == 0;
}

static int
zeroBasedDayOfYear(int year, int month, int day)
{
    static const int daysBeforeMonth[] = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    int dayOfYear = daysBeforeMonth[month - 1] + day - 1;
    if (month > 2 && isLeapYear(year)) {
        dayOfYear++;
    }
    return dayOfYear;
}

static struct tm
makeUTCReportTime(int year, int month, int day, int hour, int minute, int second)
{
    return (struct tm) {
        .tm_sec = second,
        .tm_min = minute,
        .tm_hour = hour,
        .tm_mday = day,
        .tm_mon = month - 1,
        .tm_year = year - 1900,
        .tm_yday = zeroBasedDayOfYear(year, month, day),
    };
}

@interface SentryCrashReportStore_Tests : FileBasedTestCase

@property (nonatomic, readwrite, retain) NSString *appName;
@property (nonatomic, readwrite, retain) NSString *reportStorePath;
@property (atomic, readwrite, assign) int64_t reportCounter;

@end

@implementation SentryCrashReportStore_Tests

@synthesize appName = _appName;
@synthesize reportStorePath = _reportStorePath;
@synthesize reportCounter = _reportCounter;

- (NSString *)stringByRepeatingString:(NSString *)string count:(NSUInteger)count
{
    NSMutableString *result = [NSMutableString stringWithCapacity:string.length * count];
    for (NSUInteger i = 0; i < count; i++) {
        [result appendString:string];
    }
    return result;
}

- (NSString *)reportStorePathLongerThanStaticBuffer
{
    NSMutableString *path = [NSMutableString stringWithString:self.tempPath];
    while ([path lengthOfBytesUsingEncoding:NSUTF8StringEncoding]
        <= SentryCrashCRS_MAX_PATH_LENGTH + 100) {
        [path appendString:@"/abcd"];
    }
    return path;
}

- (int64_t)getReportIDFromPath:(NSString *)path
{
    const char *filename = path.lastPathComponent.UTF8String;
    const char *appName = self.appName.UTF8String;
    const size_t appNameLen = strlen(appName);
    if (strncmp(filename, appName, appNameLen) != 0) {
        return 0;
    }
    if (strncmp(filename + appNameLen, "-report-", 8) != 0) {
        return 0;
    }
    const char *hexStart = filename + appNameLen + 8;
    char *endPtr = NULL;
    const uint64_t id = strtoull(hexStart, &endPtr, 16);
    if (endPtr == hexStart || strcmp(endPtr, ".json") != 0) {
        return 0;
    }
    return (int64_t)id;
}

- (void)setUp
{
    [super setUp];
    self.appName = @"myapp";
}

- (void)tearDown
{
    [super tearDown];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.tempPath error:nil];
}

- (void)prepareReportStoreWithPathEnd:(NSString *)pathEnd
{
    self.reportStorePath = [self.tempPath stringByAppendingPathComponent:pathEnd];
    sentrycrashcrs_initialize(self.appName.UTF8String, self.reportStorePath.UTF8String);
}

- (NSArray *)getReportIDs
{
    int reportCount = sentrycrashcrs_getReportCount();
    int64_t rawReportIDs[reportCount];
    reportCount = sentrycrashcrs_getReportIDs(rawReportIDs, reportCount);
    NSMutableArray *reportIDs = [[NSMutableArray alloc] init];
    for (int i = 0; i < reportCount; i++) {
        [reportIDs addObject:@(rawReportIDs[i])];
    }
    return reportIDs;
}

- (int64_t)writeCrashReportWithStringContents:(NSString *)contents
{
    NSData *crashData = [contents dataUsingEncoding:NSUTF8StringEncoding];
    char crashReportPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getNextCrashReportPath(crashReportPath);
    [crashData writeToFile:[NSString stringWithUTF8String:crashReportPath] atomically:YES];
    return [self getReportIDFromPath:[NSString stringWithUTF8String:crashReportPath]];
}

- (int64_t)writeUserReportWithStringContents:(NSString *)contents
{
    NSData *data = [contents dataUsingEncoding:NSUTF8StringEncoding];
    return sentrycrashcrs_addUserReport(data.bytes, (int)data.length);
}

- (void)loadReportID:(int64_t)reportID reportString:(NSString *__autoreleasing *)reportString
{
    char *reportBytes = sentrycrashcrs_readReport(reportID);

    if (reportBytes == NULL) {
        reportString = nil;
    } else {
        *reportString = [[NSString alloc]
            initWithData:[NSData dataWithBytesNoCopy:reportBytes length:strlen(reportBytes)]
                encoding:NSUTF8StringEncoding];
    }
}

- (void)expectHasReportCount:(int)reportCount
{
    XCTAssertEqual(sentrycrashcrs_getReportCount(), reportCount);
}

- (void)expectReports:(NSArray *)reportIDs areStrings:(NSArray *)reportStrings
{
    for (NSUInteger i = 0; i < reportIDs.count; i++) {
        int64_t reportID = [reportIDs[i] longLongValue];
        NSString *reportString = reportStrings[i];
        NSString *loadedReportString;
        [self loadReportID:reportID reportString:&loadedReportString];
        XCTAssertEqualObjects(loadedReportString, reportString);
    }
}

- (void)testGetReportIDFromPath_whenValidFilename_shouldReturnReportID
{
    // -- Arrange --
    self.appName = @"myapp";
    NSString *path =
        [self.tempPath stringByAppendingPathComponent:@"myapp-report-0000000000000001.json"];

    // -- Act --
    int64_t reportID = [self getReportIDFromPath:path];

    // -- Assert --
    XCTAssertEqual(reportID, 1);
}

- (void)testGetReportIDFromPath_whenValidHexID_shouldReturnReportID
{
    // -- Arrange --
    self.appName = @"myapp";
    NSString *path = [self.tempPath stringByAppendingPathComponent:@"myapp-report-abc123def.json"];

    // -- Act --
    int64_t reportID = [self getReportIDFromPath:path];

    // -- Assert --
    XCTAssertEqual(reportID, (int64_t)0xabc123def);
}

- (void)testGetReportIDFromPath_whenWrongPrefix_shouldReturnZero
{
    // -- Arrange --
    self.appName = @"myapp";
    NSString *path =
        [self.tempPath stringByAppendingPathComponent:@"other-report-0000000000000001.json"];

    // -- Act --
    int64_t reportID = [self getReportIDFromPath:path];

    // -- Assert --
    XCTAssertEqual(reportID, 0);
}

- (void)testGetReportIDFromPath_whenInvalidSuffix_shouldReturnZero
{
    // -- Arrange --
    self.appName = @"myapp";
    NSString *path =
        [self.tempPath stringByAppendingPathComponent:@"myapp-report-0000000000000001.txt"];

    // -- Act --
    int64_t reportID = [self getReportIDFromPath:path];

    // -- Assert --
    XCTAssertEqual(reportID, 0);
}

- (void)testGetReportIDFromPath_whenNoReportSegment_shouldReturnZero
{
    // -- Arrange --
    self.appName = @"myapp";
    NSString *path = [self.tempPath stringByAppendingPathComponent:@"myapp-0000000000000001.json"];

    // -- Act --
    int64_t reportID = [self getReportIDFromPath:path];

    // -- Assert --
    XCTAssertEqual(reportID, 0);
}

- (void)testReportCount_whenDirectoryContainsMalformedFiles_shouldIgnoreThem
{
    // The production parser getReportIDFromFilename in SentryCrashReportStore.c is `static`, so
    // it cannot be called directly from tests. This test exercises it indirectly: it asks the
    // store to enumerate reports while the directory also contains files whose names do not
    // match the expected "AppName-report-<hex>.json" template, and asserts those files are
    // filtered out (reportID == 0 means "ignore this entry"). This guards the strncmp + strtoull
    // refactor that replaced the previous sscanf-based parser.
    [self prepareReportStoreWithPathEnd:@"testReportCount_whenDirectoryContainsMalformedFiles"];
    int64_t validReportID = [self writeCrashReportWithStringContents:@"valid"];

    NSArray<NSString *> *malformedFilenames = @[
        @"otherapp-report-0000000000000099.json", // wrong app prefix
        @"myapp-notreport-0000000000000099.json", // wrong middle segment
        @"myapp-report-zznothex.json", // non-hex ID
        @"myapp-report-0000000000000099.txt", // wrong extension
        @"myapp-report-.json", // empty hex ID
    ];
    for (NSString *name in malformedFilenames) {
        NSString *path = [self.reportStorePath stringByAppendingPathComponent:name];
        NSError *writeError = nil;
        [@"junk" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        XCTAssertNil(writeError, @"failed to seed malformed file %@", name);
    }

    XCTAssertEqual(
        sentrycrashcrs_getReportCount(), 1, @"Malformed filenames must not be counted as reports");

    int64_t reportIDs[1] = { 0 };
    int returned = sentrycrashcrs_getReportIDs(reportIDs, 1);
    XCTAssertEqual(returned, 1);
    XCTAssertEqual(reportIDs[0], validReportID);
}

- (void)testReportStorePathExists
{
    [self prepareReportStoreWithPathEnd:@"somereports/blah/2/x"];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.reportStorePath]);
}

- (void)testGetNextCrashReportPath_whenAppNameExceedsStaticBuffer_shouldNotOverwriteCallerBuffer
{
    // -- Arrange --
    self.appName = [self stringByRepeatingString:@"a" count:SentryCrashCRS_MAX_PATH_LENGTH + 100];
    [self
        prepareReportStoreWithPathEnd:@"testGetNextCrashReportPath_whenAppNameExceedsStaticBuffer"];
    GuardedSentryCrashCRSPathBuffer guardedPath;
    fillReportStoreCanary(&guardedPath);

    // -- Act --
    sentrycrashcrs_getNextCrashReportPath(guardedPath.path);

    // -- Assert --
    XCTAssertEqual(guardedPath.path[SentryCrashCRS_MAX_PATH_LENGTH - 1], '\0');
    XCTAssertTrue(isReportStoreCanaryIntact(&guardedPath));
}

- (void)testGetNextCrashReportPath_whenReportsPathExceedsStaticBuffer_shouldNotOverwriteCallerBuffer
{
    // -- Arrange --
    self.appName = @"AppName";
    self.reportStorePath = [self reportStorePathLongerThanStaticBuffer];
    sentrycrashcrs_initialize(self.appName.UTF8String, self.reportStorePath.UTF8String);
    GuardedSentryCrashCRSPathBuffer guardedPath;
    fillReportStoreCanary(&guardedPath);

    // -- Act --
    sentrycrashcrs_getNextCrashReportPath(guardedPath.path);

    // -- Assert --
    XCTAssertEqual(guardedPath.path[SentryCrashCRS_MAX_PATH_LENGTH - 1], '\0');
    XCTAssertTrue(isReportStoreCanaryIntact(&guardedPath));
}

- (void)testAttachmentsPath_whenOutputExceedsOnCrashBuffer_shouldNotOverwriteCallerBuffer
{
    // -- Arrange --
    self.appName = [self stringByRepeatingString:@"a" count:SentryCrashCRS_MAX_PATH_LENGTH + 100];
    [self prepareReportStoreWithPathEnd:@"testAttachmentsPath_whenOutputExceedsOnCrashBuffer"];
    GuardedSentryCrashCRSPathBuffer guardedPath;
    fillReportStoreCanary(&guardedPath);

    // -- Act --
    sentrycrashcrs_getAttachmentsPath_forReportId(INT64_MAX, guardedPath.path);

    // -- Assert --
    XCTAssertEqual(guardedPath.path[SentryCrashCRS_MAX_PATH_LENGTH - 1], '\0');
    XCTAssertTrue(isReportStoreCanaryIntact(&guardedPath));
}

- (void)testCrashReportCount1
{
    [self prepareReportStoreWithPathEnd:@"testCrashReportCount1"];
    NSString *reportContents = @"Testing";
    [self writeCrashReportWithStringContents:reportContents];
    [self expectHasReportCount:1];
}

- (void)testCrashReportCount1_WithAttachments
{
    [self prepareReportStoreWithPathEnd:@"testCrashReportCount1"];
    NSString *reportContents = @"Testing";

    char crashReportPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getNextCrashReportPath(crashReportPath);
    NSString *pathToCrashReport = [NSString stringWithUTF8String:crashReportPath];
    NSError *someError;
    [NSFileManager.defaultManager
              createDirectoryAtPath:[pathToCrashReport stringByDeletingPathExtension]
        withIntermediateDirectories:true
                         attributes:nil
                              error:&someError];
    XCTAssertNil(someError);

    [self writeCrashReportWithStringContents:reportContents];
    [self expectHasReportCount:1];
}

- (void)testStoresLoadsOneCrashReport
{
    [self prepareReportStoreWithPathEnd:@"testStoresLoadsOneCrashReport"];
    NSString *reportContents = @"Testing";
    int64_t reportID = [self writeCrashReportWithStringContents:reportContents];
    [self expectReports:@[ @(reportID) ] areStrings:@[ reportContents ]];
}

- (void)testReadReport_whenSizeIsWithinLimit_shouldReadEntireReport
{
    // -- Arrange --
    [self prepareReportStoreWithPathEnd:NSStringFromSelector(_cmd)];

    const NSUInteger reportLengths[] = { 1999999, 2000000, 2000001, 19999999, 20000000 };

    for (NSUInteger i = 0; i < sizeof(reportLengths) / sizeof(reportLengths[0]); i++) {
        @autoreleasepool {
            NSUInteger length = reportLengths[i];
            NSString *contents = [@"start" stringByPaddingToLength:length
                                                        withString:@"x"
                                                   startingAtIndex:0];
            int64_t reportID = [self writeCrashReportWithStringContents:contents];

            // -- Act --
            char *report = sentrycrashcrs_readReport(reportID);

            // -- Assert --
            XCTAssertTrue(report != NULL);

            if (report != NULL) {
                XCTAssertEqual(strlen(report), length);

                if (strlen(report) == length) {
                    XCTAssertEqual(memcmp(report, contents.UTF8String, length), 0);
                }

                free(report);
            }

            sentrycrashcrs_deleteReportWithID(reportID);
        }
    }
}

- (void)testReadReport_whenSizeExceedsLimit_shouldKeepReadBounded
{
    // -- Arrange --
    [self prepareReportStoreWithPathEnd:NSStringFromSelector(_cmd)];
    NSString *contents = [@"!" stringByPaddingToLength:20000001 withString:@"x" startingAtIndex:0];
    int64_t reportID = [self writeCrashReportWithStringContents:contents];

    // -- Act --
    char *report = sentrycrashcrs_readReport(reportID);

    // -- Assert --
    XCTAssertTrue(report != NULL);

    if (report != NULL) {
        // The file utility preserves the tail of oversized files, not the beginning.
        XCTAssertEqual(strlen(report), 20000000);

        if (strlen(report) == 20000000) {
            XCTAssertEqual(memcmp(report, contents.UTF8String + 1, 20000000), 0);
        }

        free(report);
    }
}

- (NSDictionary *)readFixedReportWithID:(int64_t)reportID
{
    char *rawReport = sentrycrashcrs_readReport(reportID);
    XCTAssertTrue(rawReport != NULL);
    if (rawReport == NULL) {
        return nil;
    }

    char *fixedReport = sentrycrashcrf_fixupCrashReport(rawReport);
    free(rawReport);
    XCTAssertTrue(fixedReport != NULL);
    if (fixedReport == NULL) {
        return nil;
    }

    NSData *data = [NSData dataWithBytesNoCopy:fixedReport
                                        length:strlen(fixedReport)
                                  freeWhenDone:YES];
    NSError *error = nil;

    NSDictionary *decoded = [SentryCrashJSONCodec decode:data
                                                 options:SentryCrashJSONDecodeOptionNone
                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(decoded);

    return decoded;
}

- (void)testReadReport_whenLargeNSExceptionReport_shouldFixAndDecodeEntireReport
{
    // -- Arrange --
    [self prepareReportStoreWithPathEnd:NSStringFromSelector(_cmd)];
    // The crash writer stores the exception reason twice. Each value fits the decoder's
    // scratch buffer, but together they exceed the previous 2 MB report-read limit.
    NSString *reason = [@"" stringByPaddingToLength:1100000 withString:@"a" startingAtIndex:0];
    NSDictionary *report = @{
        @"report" : @ { @"timestamp" : @0 },
        @"crash" : @ {
            @"error" : @ {
                @"type" : @"nsexception",
                @"reason" : reason,
                @"nsexception" : @ { @"name" : @"NSException", @"reason" : reason }
            }
        }
    };
    NSError *error = nil;

    NSData *data = [NSJSONSerialization dataWithJSONObject:report
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];

    XCTAssertNil(error);
    XCTAssertGreaterThan(data.length, 2000000);

    int64_t reportID = sentrycrashcrs_addUserReport(data.bytes, (int)data.length);

    // -- Act --
    NSDictionary *decoded = [self readFixedReportWithID:reportID];

    // -- Assert --
    XCTAssertEqualObjects(decoded[@"report"][@"timestamp"], @"1970-01-01T00:00:00Z");

    // Avoid dumping megabytes of text into the test log on failure.
    XCTAssertTrue([decoded[@"crash"][@"error"][@"reason"] isEqualToString:reason]);
    XCTAssertTrue([decoded[@"crash"][@"error"][@"nsexception"][@"reason"] isEqualToString:reason]);
}

- (void)testReadReport_whenReportIsAtSizeLimit_shouldFixAndDecodeEntireReport
{
    // -- Arrange --
    [self prepareReportStoreWithPathEnd:NSStringFromSelector(_cmd)];

    // Exercise aggregate report size without exceeding the separate per-string limit.
    NSString *value = [@"" stringByPaddingToLength:999990 withString:@"a" startingAtIndex:0];
    NSMutableArray *values = [NSMutableArray array];

    for (NSUInteger i = 0; i < 20; i++) {
        [values addObject:value];
    }

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"values" : values }
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    XCTAssertNil(error);

    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertLessThanOrEqual(json.length, 20000000);

    json = [json stringByPaddingToLength:20000000 withString:@" " startingAtIndex:0];
    int64_t reportID = [self writeCrashReportWithStringContents:json];

    // -- Act --
    NSDictionary *decoded = [self readFixedReportWithID:reportID];

    // -- Assert --
    NSArray *decodedValues = decoded[@"values"];
    XCTAssertEqual(decodedValues.count, values.count);

    for (NSString *decodedValue in decodedValues) {
        XCTAssertEqual(decodedValue.length, value.length);
        XCTAssertTrue([decodedValue isEqualToString:value]);
    }
}

- (void)testStoresLoadsOneUserReport
{
    [self prepareReportStoreWithPathEnd:@"testStoresLoadsOneUserReport"];
    NSString *reportContents = @"Testing";
    int64_t reportID = [self writeUserReportWithStringContents:reportContents];
    [self expectReports:@[ @(reportID) ] areStrings:@[ reportContents ]];
}

- (void)testStoresLoadsMultipleReports
{
    [self prepareReportStoreWithPathEnd:@"testStoresLoadsMultipleReports"];
    NSMutableArray *reportIDs = [[NSMutableArray alloc] init];
    NSArray *reportContents = @[ @"report1", @"report2", @"report3", @"report4" ];
    [reportIDs addObject:@([self writeCrashReportWithStringContents:reportContents[0]])];
    [reportIDs addObject:@([self writeUserReportWithStringContents:reportContents[1]])];
    [reportIDs addObject:@([self writeUserReportWithStringContents:reportContents[2]])];
    [reportIDs addObject:@([self writeCrashReportWithStringContents:reportContents[3]])];
    [self expectHasReportCount:4];
    [self expectReports:reportIDs areStrings:reportContents];
}

- (void)testDeleteAllReports
{
    [self prepareReportStoreWithPathEnd:@"testDeleteAllReports"];
    [self writeCrashReportWithStringContents:@"1"];
    [self writeUserReportWithStringContents:@"2"];
    [self writeUserReportWithStringContents:@"3"];
    [self writeCrashReportWithStringContents:@"4"];
    [self expectHasReportCount:4];
    sentrycrashcrs_deleteAllReports();
    [self expectHasReportCount:0];
}

- (void)testPruneReports
{
    int reportStorePrunesTo = 7;
    sentrycrashcrs_setMaxReportCount(reportStorePrunesTo);
    [self prepareReportStoreWithPathEnd:@"testDeleteAllReports"];
    int64_t prunedReportID = [self writeUserReportWithStringContents:@"u1"];
    [self writeCrashReportWithStringContents:@"c1"];
    [self writeUserReportWithStringContents:@"u2"];
    [self writeCrashReportWithStringContents:@"c2"];
    [self writeCrashReportWithStringContents:@"c3"];
    [self writeUserReportWithStringContents:@"u3"];
    [self writeCrashReportWithStringContents:@"c4"];
    [self writeCrashReportWithStringContents:@"c5"];
    [self expectHasReportCount:8];
    // Calls sentrycrashcrs_initialize() again, which prunes the reports.
    [self prepareReportStoreWithPathEnd:@"testDeleteAllReports"];
    [self expectHasReportCount:reportStorePrunesTo];
    NSArray *reportIDs = [self getReportIDs];
    XCTAssertFalse([reportIDs containsObject:@(prunedReportID)]);
}

- (void)testStoresLoadsWithUnicodeAppName
{
    self.appName = @"ЙогуртЙод";
    [self prepareReportStoreWithPathEnd:@"testStoresLoadsWithUnicodeAppName"];
    NSString *reportContents = @"Testing";
    int64_t reportID = [self writeCrashReportWithStringContents:reportContents];
    [self expectReports:@[ @(reportID) ] areStrings:@[ reportContents ]];
}

- (void)test_AttachmentsPath_forReportId
{
    self.appName = @"AppName";
    [self prepareReportStoreWithPathEnd:@"/ReportPath"];
    uint64_t reportId = 84568454541;

    char attachmentsPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getAttachmentsPath_forReportId(reportId, attachmentsPath);

    XCTAssertEqualObjects([NSString stringWithUTF8String:attachmentsPath],
        [self.tempPath stringByAppendingPathComponent:
                @"/ReportPath/AppName-report-00000013b0ac358d-attachments"]);
}

- (void)test_AttachmentsPath_forReport
{
    self.appName = @"AppName";
    [self prepareReportStoreWithPathEnd:@"/ReportPath"];

    uint64_t reportId = 84568454541;

    char reportPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getCrashReportPathById(reportId, reportPath);

    char attachmentsPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getAttachmentsPath_forReport(reportPath, attachmentsPath);

    XCTAssertEqualObjects([NSString stringWithUTF8String:attachmentsPath],
        [self.tempPath stringByAppendingPathComponent:
                @"/ReportPath/AppName-report-00000013b0ac358d-attachments"]);
}

- (void)testInitializeIDs_whenUTCDateProducesZeroLowBits_shouldKeepHighBits
{
    // -- Arrange --
    [self prepareReportStoreWithPathEnd:
            @"testInitializeIDs_whenUTCDateProducesZeroLowBits_shouldKeepHighBits"];
    // 2026-06-23 22:01:27 UTC produces a shifted base ID with zero low 32 bits,
    // but non-zero high bits.
    struct tm reportTime = makeUTCReportTime(2026, 6, 23, 22, 1, 27);
    sentrycrashcrs_initializeIDsWithTimeForTests(&reportTime);

    // -- Act --
    int64_t reportID = [self writeCrashReportWithStringContents:@"Testing"];

    // -- Assert --
    XCTAssertEqual(reportID, INT64_C(0x00792dee00000000));
    [self expectHasReportCount:1];
}

- (void)test_initializeIDs
{
    self.appName = @"AppName";

    [self prepareReportStoreWithPathEnd:@"/ReportPath"];

    char firstReportPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getNextCrashReportPath(firstReportPath);

    // Unique Ids are created based on the time,
    // thats why we sleep for 1 second, to see a different Id being created
    // during initialization.
    [NSThread sleepForTimeInterval:1];
    [self prepareReportStoreWithPathEnd:@"/ReportPath"];

    char secondReportPath[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getNextCrashReportPath(secondReportPath);
    XCTAssertNotEqualObjects([NSString stringWithUTF8String:firstReportPath],
        [NSString stringWithUTF8String:secondReportPath]);
}

@end

#endif // !SDK_V10
