#import "FileBasedTestCase.h"
#import "SentryCrash.h"
#include "SentryCrashReportStore.h"

@interface SentryCrashTests : FileBasedTestCase

@end

@interface
SentryCrash ()

- (NSString *)clearBundleName:(NSString *)filename;

- (NSArray *)getAttachmentPaths:(int64_t)reportID;

@end

@implementation SentryCrashTests

- (void)tearDown
{
    [super tearDown];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.tempPath error:nil];
}

- (void)test_getScreenshots_CheckName
{
    [self initReport:12 withScreenshots:1];

    SentryCrash *sentryCrash = [[SentryCrash alloc]
        initWithBasePath:[self.tempPath stringByAppendingPathComponent:@"Reports"]];
    NSArray *files = [sentryCrash getAttachmentPaths:12];

    XCTAssertEqual(files.count, 1);
    XCTAssertEqualObjects(files.firstObject,
        [self.tempPath stringByAppendingPathComponent:
                           @"Reports/AppName-report-000000000000000c-attachments/0.png"]);
}

- (void)test_getScreenshots_TwoFiles
{
    [self initReport:12 withScreenshots:2];

    SentryCrash *sentryCrash = [[SentryCrash alloc]
        initWithBasePath:[self.tempPath stringByAppendingPathComponent:@"Reports"]];
    NSArray *files = [sentryCrash getAttachmentPaths:12];
    XCTAssertEqual(files.count, 2);
}

- (void)test_cleanBundleName
{
    SentryCrash *sentryCrash = [[SentryCrash alloc] initWithBasePath:[self.tempPath stringByAppendingPathComponent:@"Something"]];

    NSString *clearedBundleName = [sentryCrash clearBundleName:@"Sentry/Test"];

    XCTAssertEqualObjects(clearedBundleName, @"Sentry-Test");
}

- (void)test_getScreenshots_NoFiles
{
    [self initReport:12 withScreenshots:0];

    SentryCrash *sentryCrash = [[SentryCrash alloc]
        initWithBasePath:[self.tempPath stringByAppendingPathComponent:@"Reports"]];
    NSArray *files = [sentryCrash getAttachmentPaths:12];
    XCTAssertEqual(files.count, 0);
}

- (void)test_getScreenshots_NoDirectory
{
    SentryCrash *sentryCrash = [[SentryCrash alloc]
        initWithBasePath:[self.tempPath stringByAppendingPathComponent:@"ReportsFake"]];
    NSArray *files = [sentryCrash getAttachmentPaths:12];
    XCTAssertEqual(files.count, 0);
}

- (void)initReport:(uint64_t)reportId withScreenshots:(int)amount
{
    NSString *reportStorePath = [self.tempPath stringByAppendingPathComponent:@"Reports"];
    sentrycrashcrs_initialize("AppName", reportStorePath.UTF8String);

    char reportPathBuffer[500];
    sentrycrashcrs_getAttachmentsPath_forReportId(12, reportPathBuffer);
    NSString *ssDir = [NSString stringWithUTF8String:reportPathBuffer];
    [NSFileManager.defaultManager createDirectoryAtPath:ssDir
                            withIntermediateDirectories:true
                                             attributes:nil
                                                  error:nil];

    for (int i = 0; i < amount; i++) {
        NSString *name = [NSString stringWithFormat:@"%i.png", i];
        [[name dataUsingEncoding:NSUTF8StringEncoding]
            writeToFile:[ssDir stringByAppendingPathComponent:name]
             atomically:YES];
    }
}

@end
