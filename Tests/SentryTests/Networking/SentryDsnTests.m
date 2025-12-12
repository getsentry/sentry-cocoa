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

- (void)testGetHash_ReturnsSHA1Hash
{
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username:password@getsentry.net/1"
                                      didFailWithError:nil];

    NSString *hash = [dsn getHash];

    XCTAssertNotNil(hash);
    XCTAssertEqual(hash.length, 40, @"SHA1 hash should be 40 characters");

    NSCharacterSet *hexCharacterSet =
        [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    NSCharacterSet *hashCharacterSet = [NSCharacterSet characterSetWithCharactersInString:hash];
    XCTAssertTrue([hexCharacterSet isSupersetOfSet:hashCharacterSet],
        @"Hash should only contain hexadecimal characters");
}

- (void)testGetHash_IsConsistent
{
    NSString *dsnString = @"https://username:password@getsentry.net/1";
    SentryDsn *dsn1 = [[SentryDsn alloc] initWithString:dsnString didFailWithError:nil];
    SentryDsn *dsn2 = [[SentryDsn alloc] initWithString:dsnString didFailWithError:nil];

    NSString *hash1 = [dsn1 getHash];
    NSString *hash2 = [dsn2 getHash];

    XCTAssertEqualObjects(hash1, hash2, @"Same DSN should produce the same hash");
}

- (void)testGetHash_DifferentDsnProducesDifferentHash
{
    SentryDsn *dsn1 = [[SentryDsn alloc] initWithString:@"https://user1:pass1@getsentry.net/1"
                                       didFailWithError:nil];
    SentryDsn *dsn2 = [[SentryDsn alloc] initWithString:@"https://user2:pass2@getsentry.net/2"
                                       didFailWithError:nil];

    NSString *hash1 = [dsn1 getHash];
    NSString *hash2 = [dsn2 getHash];

    XCTAssertNotEqualObjects(hash1, hash2, @"Different DSNs should produce different hashes");
}

@end
