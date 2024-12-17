#import "SentryByteCountFormatter.h"
#import "SentryFileIOTracker.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentrySpan.h"
#import "SentrySwizzle.h"
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

- (void)setUpSentrySDKwithEnableFileManagerSwizzling:(bool)enableFileManagerSwizzling
{
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.enableAutoPerformanceTracing = YES;
        options.enableFileIOTracing = YES;
        options.tracesSampleRate = @1;

        options.experimental.enableFileManagerSwizzling = enableFileManagerSwizzling;
    }];
}

- (void)tearDown
{
    [NSFileManager.defaultManager removeItemAtURL:fileUrl error:nil];
    if (deleteFileDirectory) {
        [NSFileManager.defaultManager removeItemAtURL:fileDirectory error:nil];
    }
    [SentrySDK close];
}

- (void)testNSFileManagerCreateFile_preiOS18macOS15tvOS18_experimentalFlagDisabled_shouldNotSwizzle
{
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        XCTSkip("Test only targets pre iOS 18, macOS 15, tvOS 18");
    }
    [self setUpSentrySDKwithEnableFileManagerSwizzling:NO];
    // Pre iOS 18, macOS 15, tvOS 18 the NSFileManager uses NSData, which is swizzled.
    // As NSData swizzling can not be disabled, it will still record a span
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                              spanCount:1
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
    [self setUpSentrySDKwithEnableFileManagerSwizzling:YES];
    // Pre iOS 18, macOS 15, tvOS 18 the NSFileManager uses NSData, which is swizzled.
    // As NSData swizzling can not be disabled, it will still record a span
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                              spanCount:1
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
    [self setUpSentrySDKwithEnableFileManagerSwizzling:NO];
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
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
    [self setUpSentrySDKwithEnableFileManagerSwizzling:YES];
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
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

        if ([operation isEqualToString:SENTRY_FILE_READ_OPERATION]) {
            XCTAssertEqualObjects(ioSpan.spanDescription, filename);
        } else {
            NSString *expectedString = [NSString stringWithFormat:@"%@ (%@)", filename,
                [SentryByteCountFormatter bytesCountDescription:someData.length]];

            XCTAssertEqualObjects(ioSpan.spanDescription, expectedString);
        }
    }
}

@end
