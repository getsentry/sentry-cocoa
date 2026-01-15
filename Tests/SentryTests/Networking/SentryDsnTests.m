#import "SentryError.h"
#import "SentryMeta.h"
#import "SentryOptionsInternal.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>

@interface SentryDsnTests : XCTestCase

@end

@implementation SentryDsnTests

- (void)testMissingUsernamePassword
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testMissingScheme
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testMissingHost
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @"http:///1" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testUnsupportedProtocol
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @"ftp://sentry.io/1" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testGetEnvelopeUrl
{
    NSError *error = nil;
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username:password@getsentry.net/1"
                                      didFailWithError:&error];

    XCTAssertEqualObjects(
        [[dsn getEnvelopeEndpoint] absoluteString], @"https://getsentry.net/api/1/envelope/");
    XCTAssertNil(error);

    SentryDsn *dsn2 =
        [[SentryDsn alloc] initWithString:@"https://username:password@sentry.io/foo/bar/baz/1"
                         didFailWithError:&error];

    XCTAssertEqualObjects([[dsn2 getEnvelopeEndpoint] absoluteString],
        @"https://sentry.io/foo/bar/baz/api/1/envelope/");
    XCTAssertNil(error);
}

- (void)testInitWithInvalidString
{
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"This is invalid DSN" didFailWithError:nil];
    XCTAssertNil(dsn);
}

- (void)testGetEnvelopeDsnCachesResult
{
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username:password@getsentry.net/1"
                                      didFailWithError:nil];

    XCTAssertNotNil([dsn getEnvelopeEndpoint]);
    // Assert same reference
    XCTAssertTrue([dsn getEnvelopeEndpoint] == [dsn getEnvelopeEndpoint]);
}

@end
