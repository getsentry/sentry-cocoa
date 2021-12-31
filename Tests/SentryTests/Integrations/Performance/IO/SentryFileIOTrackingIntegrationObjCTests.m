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

@implementation SentryFileIOTrackingIntegrationObjCTests {
    NSString *filePath;
    NSURL *fileUrl;
}

- (void)inititialize
{
    NSArray *directories = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                                inDomains:NSUserDomainMask];
    NSURL *docDir = directories.firstObject;
    fileUrl = [docDir URLByAppendingPathComponent:@"TestFile"];
    filePath = fileUrl.path;
}

- (void)setUp
{
    [super setUp];
    [self inititialize];

    [[@"SOME DATA" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filePath atomically:true];

    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.enableAutoPerformanceTracking = YES;
        options.enableFileIOTracking = YES;
        options.tracesSampleRate = @1;
    }];
}

- (void)test_dataWithContentsOfFile
{
    [self assertTransaction:^{ [NSData dataWithContentsOfFile:self->filePath]; }];
}

- (void)test_dataWithContentsOfFileOptionsError
{
    [self assertTransaction:^{
        [NSData dataWithContentsOfFile:self->filePath options:NSDataReadingUncached error:nil];
    }];
}

- (void)test_dataWithContentsOfURL
{
    [self assertTransaction:^{ [NSData dataWithContentsOfURL:self->fileUrl]; }];
}

- (void)test_dataWithContentsOfURLOptionsError
{
    [self assertTransaction:^{
        [NSData dataWithContentsOfURL:self->fileUrl options:NSDataReadingUncached error:nil];
    }];
}

- (void)test_initWithContentsOfURL
{
    [self assertTransaction:^{
        __unused NSData *result = [[NSData alloc] initWithContentsOfURL:self->fileUrl];
    }];
}

- (void)assertTransaction:(void (^)(void))block
{
    SentryTracer *parentTransaction = [SentrySDK startTransactionWithName:@"Transaction"
                                                                operation:@"Test"
                                                              bindToScope:YES];

    block();

    XCTAssertEqual(parentTransaction.children.count, 1);
}

@end
