#import "SentryNSDataUtils.h"
#import <XCTest/XCTest.h>

@interface SentryNSDataCompressionTests : XCTestCase

@end

@implementation SentryNSDataCompressionTests

- (void)testCompress
{
    NSUInteger numBytes = 1000000;
    NSMutableData *data = [NSMutableData dataWithCapacity:numBytes];
    for (NSUInteger i = 0; i < numBytes; i++) {
        unsigned char byte = (unsigned char)i;
        [data appendBytes:&byte length:1];
    }

    NSError *error = nil;
    NSData *original = [NSData dataWithData:data];
    NSData *compressed = sentry_gzippedWithCompressionLevel(original, -1, &error);
    XCTAssertNil(error);
    XCTAssertNotNil(compressed);
}

- (void)testCompressEmpty
{
    NSError *error = nil;
    NSData *original = [NSData data];
    NSData *compressed = sentry_gzippedWithCompressionLevel(original, -1, &error);
    XCTAssertNil(error, @"");

    XCTAssertEqualObjects(compressed, original, @"");
}

- (void)testCompressNilError
{
    NSUInteger numBytes = 1000;
    NSMutableData *data = [NSMutableData dataWithCapacity:numBytes];
    for (NSUInteger i = 0; i < numBytes; i++) {
        unsigned char byte = (unsigned char)i;
        [data appendBytes:&byte length:1];
    }

    NSData *original = [NSData dataWithData:data];
    NSData *compressed = sentry_gzippedWithCompressionLevel(original, -1, nil);
    XCTAssertNotNil(compressed);
}

- (void)testCompressEmptyNilError
{
    NSData *original = [NSData data];
    NSData *compressed = sentry_gzippedWithCompressionLevel(original, -1, nil);

    XCTAssertEqualObjects(compressed, original, @"");
}

- (void)testBogusParamerte
{
    NSUInteger numBytes = 1000;
    NSMutableData *data = [NSMutableData dataWithCapacity:numBytes];
    for (NSUInteger i = 0; i < numBytes; i++) {
        unsigned char byte = (unsigned char)i;
        [data appendBytes:&byte length:1];
    }

    NSError *error = nil;
    NSData *original = [NSData dataWithData:data];

    NSData *compressed = sentry_gzippedWithCompressionLevel(original, INT_MAX, &error);
    ;
    XCTAssertNil(compressed);
    XCTAssertNotNil(error);
}

@end
