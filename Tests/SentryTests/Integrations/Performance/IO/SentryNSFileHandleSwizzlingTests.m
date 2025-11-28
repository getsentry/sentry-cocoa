#import "SentryByteCountFormatter.h"
#import "SentryDefaultThreadInspector.h"
#import "SentryFileIOTrackerHelper.h"
#import "SentryNSFileHandleSwizzling.h"
#import "SentrySpan.h"
#import "SentrySpanOperation.h"
#import "SentrySwizzle.h"
#import "SentryTests-Swift.h"
#import "SentryTracer.h"
#import <SentrySwift.h>
#import <XCTest/XCTest.h>

@interface SentryNSFileHandleSwizzlingTests : XCTestCase

@end

@implementation SentryNSFileHandleSwizzlingTests {
    NSString *filePath;
    NSURL *fileUrl;
    NSData *someData;
    NSURL *fileDirectory;
    BOOL deleteFileDirectory;
    SentryFileIOTracker *tracker;
    NSFileHandle *fileHandleForReading;
    NSFileHandle *fileHandleForWriting;
}

- (void)inititialize
{
    NSArray *directories = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                                inDomains:NSUserDomainMask];
    fileDirectory = directories.firstObject;

    if (![NSFileManager.defaultManager fileExistsAtPath:fileDirectory.path]) {
        deleteFileDirectory = true;
        [NSFileManager.defaultManager createDirectoryAtURL:fileDirectory
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    }

    fileUrl = [fileDirectory URLByAppendingPathComponent:@"TestFile"];
    filePath = fileUrl.path;
}

- (void)setUp
{
    [super setUp];
    [self inititialize];

    someData = [@"SOME DATA" dataUsingEncoding:NSUTF8StringEncoding];
    [someData writeToFile:filePath atomically:true];
    fileHandleForReading = [NSFileHandle fileHandleForReadingAtPath:filePath];

    NSString *writeFilePath = [fileDirectory URLByAppendingPathComponent:@"TestFileWrite"].path;
    [NSFileManager.defaultManager createFileAtPath:writeFilePath contents:nil attributes:nil];
    fileHandleForWriting = [NSFileHandle fileHandleForWritingAtPath:writeFilePath];
}

- (void)setUpNSFileHandleSwizzlingWithEnabledFlag:(bool)enableFileHandleSwizzling
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.enableFileHandleSwizzling = enableFileHandleSwizzling;

    self->tracker = [FileIOTrackerTestHelpers makeTrackerWithOptions:options];
    [tracker enable];

    [[SentryNSFileHandleSwizzling shared] startWithOptions:options tracker:self->tracker];
}

- (void)tearDown
{
    [fileHandleForReading closeFile];
    [fileHandleForWriting closeFile];
    [NSFileManager.defaultManager removeItemAtURL:fileUrl error:nil];
    NSString *writeFilePath = [fileDirectory URLByAppendingPathComponent:@"TestFileWrite"].path;
    [NSFileManager.defaultManager removeItemAtPath:writeFilePath error:nil];
    if (deleteFileDirectory) {
        [NSFileManager.defaultManager removeItemAtURL:fileDirectory error:nil];
    }
    [self->tracker disable];
    [[SentryNSFileHandleSwizzling shared] stop];
}

- (void)testNSFileHandleReadDataOfLength_experimentalFlagDisabled_shouldNotSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:NO];
    [self assertTransactionForOperation:SentrySpanOperationFileRead
                              spanCount:0
                                  block:^{
                                      [self->fileHandleForReading
                                          readDataOfLength:self->someData.length];
                                  }];
}

- (void)testNSFileHandleReadDataOfLength_experimentalFlagEnabled_shouldSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:YES];
    [self assertTransactionForOperation:SentrySpanOperationFileRead
                              spanCount:1
                                  block:^{
                                      NSData *data = [self->fileHandleForReading
                                          readDataOfLength:self->someData.length];
                                      XCTAssertEqual(data.length, self->someData.length);
                                  }];
}

- (void)testNSFileHandleReadDataToEndOfFile_experimentalFlagDisabled_shouldNotSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:NO];
    [self assertTransactionForOperation:SentrySpanOperationFileRead
                              spanCount:0
                                  block:^{ [self->fileHandleForReading readDataToEndOfFile]; }];
}

- (void)testNSFileHandleReadDataToEndOfFile_experimentalFlagEnabled_shouldSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:YES];
    [self assertTransactionForOperation:SentrySpanOperationFileRead
                              spanCount:1
                                  block:^{
                                      NSData *data =
                                          [self->fileHandleForReading readDataToEndOfFile];
                                      XCTAssertEqual(data.length, self->someData.length);
                                  }];
}

- (void)testNSFileHandleWriteData_experimentalFlagDisabled_shouldNotSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:NO];
    [self
        assertTransactionForOperation:SentrySpanOperationFileWrite
                            spanCount:0
                                block:^{ [self->fileHandleForWriting writeData:self->someData]; }];
}

- (void)testNSFileHandleWriteData_experimentalFlagEnabled_shouldSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:YES];
    [self
        assertTransactionForOperation:SentrySpanOperationFileWrite
                            spanCount:1
                                block:^{ [self->fileHandleForWriting writeData:self->someData]; }];
}

- (void)testNSFileHandleSynchronizeFile_experimentalFlagDisabled_shouldNotSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:NO];
    [self assertTransactionForOperation:SentrySpanOperationFileWrite
                              spanCount:0
                                  block:^{ [self->fileHandleForWriting synchronizeFile]; }];
}

- (void)testNSFileHandleSynchronizeFile_experimentalFlagEnabled_shouldSwizzle
{
    [self setUpNSFileHandleSwizzlingWithEnabledFlag:YES];
    [self assertTransactionForOperation:SentrySpanOperationFileWrite
                              spanCount:1
                                  block:^{ [self->fileHandleForWriting synchronizeFile]; }];
}

- (void)assertTransactionForOperation:(NSString *)operation
                            spanCount:(NSUInteger)spanCount
                                block:(void (^)(void))block
{
    SentryTracer *parentTransaction
        = (SentryTracer *)[SentrySDK startTransactionWithName:@"Transaction"
                                                    operation:@"Test"
                                                  bindToScope:YES];

    block();

    XCTAssertEqual(parentTransaction.children.count, spanCount);

    SentrySpan *ioSpan = (SentrySpan *)parentTransaction.children.firstObject;
    if (spanCount > 0) {
        if ([operation isEqualToString:SentrySpanOperationFileRead]) {
            XCTAssertEqual([ioSpan.data[@"file.size"] unsignedIntValue], someData.length);
        } else if ([operation isEqualToString:SentrySpanOperationFileWrite]) {
            if (ioSpan.data[@"file.size"] != nil) {
                XCTAssertEqual([ioSpan.data[@"file.size"] unsignedIntValue], someData.length);
            }
        }

        if (@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)) {
            XCTAssertNotNil(ioSpan.data[@"file.path"]);
        }
        XCTAssertEqualObjects(operation, ioSpan.operation);

        NSString *filename = filePath.lastPathComponent;

        if ([operation isEqualToString:SentrySpanOperationFileRead]) {
            XCTAssertEqualObjects(ioSpan.spanDescription, filename);
        } else {
            if (ioSpan.data[@"file.size"] != nil) {
                NSString *expectedString = [NSString stringWithFormat:@"%@ (%@)", filename,
                    [SentryByteCountFormatter bytesCountDescription:someData.length]];

                XCTAssertEqualObjects(ioSpan.spanDescription, expectedString);
            } else {
                XCTAssertEqualObjects(ioSpan.spanDescription, filename);
            }
        }
    }
}

@end
