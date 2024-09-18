#import "SentryByteCountFormatter.h"
#import "SentryNSDataTracker.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentrySpan.h"
#import "SentrySwizzle.h"
#import "SentryTracer.h"
#import <XCTest/XCTest.h>

@interface SentryFileIOTrackingIntegrationObjCTests : XCTestCase

@end

/**
 * Not all NSData methods have an equivalent in Swift.
 * These tests assure NSData methods are working properly.
 */
@implementation SentryFileIOTrackingIntegrationObjCTests {
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

    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.enableAutoPerformanceTracing = YES;
        options.enableFileIOTracing = YES;
        options.tracesSampleRate = @1;
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

- (void)test_dataWithContentsOfFile
{
    [self assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                  block:^{
                                      [self assertData:[NSData
                                                           dataWithContentsOfFile:self->filePath]];
                                  }];
}

- (void)test_dataWithContentsOfFileOptionsError
{
    [self
        assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                block:^{
                                    [self
                                        assertData:[NSData
                                                       dataWithContentsOfFile:self->filePath
                                                                      options:NSDataReadingUncached
                                                                        error:nil]];
                                }];
}

- (void)test_dataWithContentsOfURL
{
    [self
        assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                block:^{
                                    [self assertData:[NSData dataWithContentsOfURL:self->fileUrl]];
                                }];
}

- (void)test_dataWithContentsOfURLOptionsError
{
    [self
        assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                block:^{
                                    [self assertData:[NSData
                                                         dataWithContentsOfURL:self->fileUrl
                                                                       options:NSDataReadingUncached
                                                                         error:nil]];
                                }];
}

- (void)test_initWithContentsOfURL
{
    [self assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                  block:^{
                                      [self assertData:[[NSData alloc]
                                                           initWithContentsOfURL:self->fileUrl]];
                                  }];
}

- (void)test_initWithContentsOfFile
{
    [self assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                  block:^{
                                      [self assertData:[[NSData alloc]
                                                           initWithContentsOfFile:self->filePath]];
                                  }];
}

- (void)test_writeToFileAtomically
{
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                                  block:^{
                                      [self->someData writeToFile:self->filePath atomically:true];
                                  }];
    [self assertDataWritten];
}

- (void)test_writeToUrlAtomically
{
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                                  block:^{
                                      [self->someData writeToURL:self->fileUrl atomically:true];
                                  }];
    [self assertDataWritten];
}

- (void)test_writeToFileOptionsError
{
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                                  block:^{
                                      [self->someData writeToFile:self->filePath
                                                          options:NSDataWritingAtomic
                                                            error:nil];
                                  }];
    [self assertDataWritten];
}

- (void)test_writeToUrlOptionsError
{
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                                  block:^{
                                      [self->someData writeToURL:self->fileUrl
                                                         options:NSDataWritingAtomic
                                                           error:nil];
                                  }];
    [self assertDataWritten];
}

- (void)test_NSFileManagerContentAtPath
{
    [self assertTransactionForOperation:SENTRY_FILE_READ_OPERATION
                                  block:^{
                                      [self assertData:[NSFileManager.defaultManager
                                                           contentsAtPath:self->filePath]];
                                  }];
}

- (void)test_NSFileManagerCreateFile
{
    [self assertTransactionForOperation:SENTRY_FILE_WRITE_OPERATION
                                  block:^{
                                      [NSFileManager.defaultManager createFileAtPath:self->filePath
                                                                            contents:self->someData
                                                                          attributes:nil];
                                  }];
    [self assertDataWritten];
}

- (void)assertData:(NSData *)data
{
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    XCTAssertEqualObjects(content, @"SOME DATA");
    XCTAssertEqual(data.length, someData.length);
}

- (void)assertDataWritten
{
    [self assertData:[NSData dataWithContentsOfFile:filePath]];
}

- (void)assertTransactionForOperation:(NSString *)operation block:(void (^)(void))block
{
    SentryTracer *parentTransaction = [SentrySDK startTransactionWithName:@"Transaction"
                                                                operation:@"Test"
                                                              bindToScope:YES];

    block();

    SentrySpan *ioSpan = parentTransaction.children.firstObject;

    XCTAssertEqual(parentTransaction.children.count, 1);
    XCTAssertEqual([ioSpan.data[@"file.size"] unsignedIntValue], someData.length);
    XCTAssertEqualObjects(ioSpan.data[@"file.path"], filePath);
    XCTAssertEqualObjects(operation, ioSpan.operation);

    NSString *filename = filePath.lastPathComponent;

    if ([operation isEqualToString:SENTRY_FILE_READ_OPERATION]) {
        XCTAssertEqualObjects(ioSpan.spanDescription, filename);
    } else {
        NSString *expectedString =
            [NSString stringWithFormat:@"%@ (%@)", filename,
                      [SentryByteCountFormatter bytesCountDescription:someData.length]];

        XCTAssertEqualObjects(ioSpan.spanDescription, expectedString);
    }
}

@end
