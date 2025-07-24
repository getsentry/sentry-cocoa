#import "SentryByteCountFormatter.h"
#import "SentryFileIOTracker.h"
#import "SentryNSFileManagerSwizzling.h"
#import "SentryOptions.h"
#import "SentrySpan.h"
#import "SentrySpanOperation.h"
#import "SentrySwizzle.h"
#import "SentryThreadInspector.h"
#import "SentryTracer.h"
#import <SentrySwift.h>
#import <XCTest/XCTest.h>

@interface SentryNSFileManagerSwizzlingTests : XCTestCase

@end

@implementation SentryNSFileManagerSwizzlingTests {
    NSString *filePath;
    NSURL *fileUrl;
    NSData *someData;
    NSURL *fileDirectory;
    BOOL deleteFileDirectory;
    SentryFileIOTracker *tracker;
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
}

- (void)setUpNSFileManagerSwizzlingWithEnabledFlag:(bool)enableFileManagerSwizzling
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.experimental.enableFileManagerSwizzling = enableFileManagerSwizzling;

    SentryThreadInspector *threadInspector =
        [[SentryThreadInspector alloc] initWithOptions:options];
    SentryNSProcessInfoWrapper *processInfoWrapper =
        [SentryDependencyContainer.sharedInstance processInfoWrapper];
    self->tracker = [[SentryFileIOTracker alloc] initWithThreadInspector:threadInspector
                                                      processInfoWrapper:processInfoWrapper];
    [tracker enable];

    [[SentryNSFileManagerSwizzling shared] startWithOptions:options tracker:self->tracker];
}

- (void)tearDown
{
    [NSFileManager.defaultManager removeItemAtURL:fileUrl error:nil];
    if (deleteFileDirectory) {
        [NSFileManager.defaultManager removeItemAtURL:fileDirectory error:nil];
    }
    [self->tracker disable];
    [[SentryNSFileManagerSwizzling shared] stop];
}

- (void)testNSFileManagerCreateFile_preiOS18macOS15tvOS18_experimentalFlagDisabled_shouldNotSwizzle
{
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        XCTSkip("Test only targets pre iOS 18, macOS 15, tvOS 18");
    }
    [self setUpNSFileManagerSwizzlingWithEnabledFlag:NO];
    [self assertTransactionForOperation:SentrySpanOperationFileWrite
                              spanCount:0
                                  block:^{
                                      [NSFileManager.defaultManager createFileAtPath:self->filePath
                                                                            contents:self->someData
                                                                          attributes:nil];
                                  }];
    [self assertDataWritten];
}

- (void)testNSFileManagerCreateFile_preiOS18macOS15tvOS18_experimentalFlagEnabled_shouldNotSwizzle
{
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        XCTSkip("Test only targets pre iOS 18, macOS 15, tvOS 18");
    }
    [self setUpNSFileManagerSwizzlingWithEnabledFlag:YES];
    [self assertTransactionForOperation:SentrySpanOperationFileWrite
                              spanCount:0
                                  block:^{
                                      [NSFileManager.defaultManager createFileAtPath:self->filePath
                                                                            contents:self->someData
                                                                          attributes:nil];
                                  }];
    [self assertDataWritten];
}

- (void)
    testNSFileManagerCreateFile_iOS18macOS15tvOS18OrLater_experimentalFlagDisabled_shouldNotSwizzle
{
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        // continue
    } else {
        XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later");
    }
    [self setUpNSFileManagerSwizzlingWithEnabledFlag:NO];
    [self assertTransactionForOperation:SentrySpanOperationFileWrite
                              spanCount:0
                                  block:^{
                                      [NSFileManager.defaultManager createFileAtPath:self->filePath
                                                                            contents:self->someData
                                                                          attributes:nil];
                                  }];
    [self assertDataWritten];
}

- (void)testNSFileManagerCreateFile_iOS18macOS15tvOS18OrLater_experimentalFlagEnabled_shouldSwizzle
{
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        // continue
    } else {
        XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later");
    }
    [self setUpNSFileManagerSwizzlingWithEnabledFlag:YES];
    [self assertTransactionForOperation:SentrySpanOperationFileWrite
                              spanCount:1
                                  block:^{
                                      [NSFileManager.defaultManager createFileAtPath:self->filePath
                                                                            contents:self->someData
                                                                          attributes:nil];
                                  }];
    [self assertDataWritten];
}

- (void)assertDataWritten
{
    [self assertData:[NSData dataWithContentsOfFile:filePath]];
}

- (void)assertData:(NSData *)data
{
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    XCTAssertEqualObjects(content, @"SOME DATA");
    XCTAssertEqual(data.length, someData.length);
}

- (void)assertTransactionForOperation:(NSString *)operation
                            spanCount:(NSUInteger)spanCount
                                block:(void (^)(void))block
{
    SentryTracer *parentTransaction = [SentrySDK startTransactionWithName:@"Transaction"
                                                                operation:@"Test"
                                                              bindToScope:YES];

    block();

    XCTAssertEqual(parentTransaction.children.count, spanCount);

    SentrySpan *ioSpan = parentTransaction.children.firstObject;
    if (spanCount > 0) {
        XCTAssertEqual([ioSpan.data[@"file.size"] unsignedIntValue], someData.length);
        XCTAssertEqualObjects(ioSpan.data[@"file.path"], filePath);
        XCTAssertEqualObjects(operation, ioSpan.operation);

        NSString *filename = filePath.lastPathComponent;

        if ([operation isEqualToString:SentrySpanOperationFileRead]) {
            XCTAssertEqualObjects(ioSpan.spanDescription, filename);
        } else {
            NSString *expectedString = [NSString stringWithFormat:@"%@ (%@)", filename,
                [SentryByteCountFormatter bytesCountDescription:someData.length]];

            XCTAssertEqualObjects(ioSpan.spanDescription, expectedString);
        }
    }
}

@end
