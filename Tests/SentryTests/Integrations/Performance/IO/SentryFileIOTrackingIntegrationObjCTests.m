#import "SentryNSDataTracker.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentrySpan.h"
#import "SentrySwizzle.h"
#import "SentryTracer.h"
#import <XCTest/XCTest.h>

@interface
SentryTracer ()

@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> *children;

@end

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
}

- (void)inititialize
{
    NSArray *directories = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                                inDomains:NSUserDomainMask];
    NSURL *docDir = directories.firstObject;

    [NSFileManager.defaultManager createDirectoryAtURL:docDir
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];

    fileUrl = [docDir URLByAppendingPathComponent:@"TestFile"];
    filePath = fileUrl.path;
}

- (void)setUp
{
    [super setUp];
    [self inititialize];

    someData = [@"SOME DATA" dataUsingEncoding:NSUTF8StringEncoding];
    [someData writeToFile:filePath atomically:true];

    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.enableAutoPerformanceTracking = YES;
        options.enableFileIOTracking = YES;
        options.tracesSampleRate = @1;
    }];
}

- (void)test_dataWithContentsOfFile
{
    [self assertTransaction:^{ [self assertData:[NSData dataWithContentsOfFile:self->filePath]]; }];
}

- (void)test_dataWithContentsOfFileOptionsError
{
    [self assertTransaction:^{
        [self assertData:[NSData dataWithContentsOfFile:self->filePath
                                                options:NSDataReadingUncached
                                                  error:nil]];
    }];
}

- (void)test_dataWithContentsOfURL
{
    [self assertTransaction:^{ [self assertData:[NSData dataWithContentsOfURL:self->fileUrl]]; }];
}

- (void)test_dataWithContentsOfURLOptionsError
{
    [self assertTransaction:^{
        [self assertData:[NSData dataWithContentsOfURL:self->fileUrl
                                               options:NSDataReadingUncached
                                                 error:nil]];
    }];
}

- (void)test_initWithContentsOfURL
{
    [self assertTransaction:^{
        [self assertData:[[NSData alloc] initWithContentsOfURL:self->fileUrl]];
    }];
}

- (void)test_initWithContentsOfFile
{
    [self assertTransaction:^{
        [self assertData:[[NSData alloc] initWithContentsOfFile:self->filePath]];
    }];
}

- (void)test_writeToFileAtomically
{
    [self assertTransaction:^{ [self->someData writeToFile:self->filePath atomically:true]; }];
    [self assertDataWritten];
}

- (void)test_writeToUrlAtomically
{
    [self assertTransaction:^{ [self->someData writeToURL:self->fileUrl atomically:true]; }];
    [self assertDataWritten];
}

- (void)test_writeToFileOptionsError
{
    [self assertTransaction:^{
        [self->someData writeToFile:self->filePath options:NSDataWritingAtomic error:nil];
    }];
    [self assertDataWritten];
}

- (void)test_writeToUrlOptionsError
{
    [self assertTransaction:^{
        [self->someData writeToURL:self->fileUrl options:NSDataWritingAtomic error:nil];
    }];
    [self assertDataWritten];
}

- (void)test_NSFileManagerContentAtPath
{
    [self assertTransaction:^{
        [self assertData:[NSFileManager.defaultManager contentsAtPath:self->filePath]];
    }];
}

- (void)test_NSFileManagerCreateFile
{
    [self assertTransaction:^{
        [NSFileManager.defaultManager createFileAtPath:self->filePath
                                              contents:self->someData
                                            attributes:nil];
    }];
    [self assertDataWritten];
}

- (void)assertData:(NSData *)data
{
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    XCTAssertTrue([content isEqualToString:@"SOME DATA"]);
    XCTAssertEqual(data.length, 9);
}

- (void)assertDataWritten
{
    [self assertData:[NSData dataWithContentsOfFile:filePath]];
}

- (void)assertTransaction:(void (^)(void))block
{
    SentryTracer *parentTransaction = [SentrySDK startTransactionWithName:@"Transaction"
                                                                operation:@"Test"
                                                              bindToScope:YES];

    block();

    SentrySpan *ioSpan = parentTransaction.children.firstObject;
    NSString *operation = ioSpan.context.operation;

    XCTAssertEqual(parentTransaction.children.count, 1);
    XCTAssertEqual([ioSpan.data[@"file.size"] unsignedIntValue], someData.length);
    XCTAssertTrue([ioSpan.data[@"file.path"] isEqualToString:filePath]);

    NSString *filename = filePath.lastPathComponent;

    if ([operation isEqualToString:SENTRY_FILE_READ_OPERATION]) {
        XCTAssertTrue([ioSpan.context.spanDescription isEqualToString:filename]);
    } else if ([operation isEqualToString:SENTRY_FILE_WRITE_OPERATION]) {
        NSString *expectedString = [NSString
            stringWithFormat:@"%@ (%@)", filename,
            [NSByteCountFormatter stringFromByteCount:someData.length
                                           countStyle:NSByteCountFormatterCountStyleBinary]];

        XCTAssertTrue([ioSpan.context.spanDescription isEqualToString:expectedString]);
    } else {
        XCTFail("Invalid operation");
    }
}

@end
