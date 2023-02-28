#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryMeta.h"
#import "SentryNSURLRequest.h"
#import "SentryOptions+HybridSDKs.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryDsnTests : XCTestCase

@end

@implementation SentryDsnTests

- (void)testMissingUsernamePassword
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testDsnHeaderUsernameAndPassword
{
    NSError *error = nil;
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username:password@sentry.io/1"
                                      didFailWithError:&error];
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:dsn
                                                                              andData:[NSData data]
                                                                     didFailWithError:&error];

    NSString *authHeader = [[NSString alloc]
        initWithFormat:@"Sentry "
                       @"sentry_version=7,sentry_client=sentry.cocoa/"
                       @"%@,sentry_timestamp=%@,sentry_key=username,sentry_"
                       @"secret=password",
        SentryMeta.versionString, @((NSInteger)[[NSDate date] timeIntervalSince1970])];

    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Sentry-Auth"], authHeader);
    XCTAssertNil(error);
}

- (void)testDsnHeaderUsername
{
    NSError *error = nil;
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username@sentry.io/1"
                                      didFailWithError:&error];
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:dsn
                                                                              andData:[NSData data]
                                                                     didFailWithError:&error];

    NSString *authHeader = [[NSString alloc]
        initWithFormat:@"Sentry "
                       @"sentry_version=7,sentry_client=sentry.cocoa/"
                       @"%@,sentry_timestamp=%@,sentry_key=username",
        SentryMeta.versionString, @((NSInteger)[[NSDate date] timeIntervalSince1970])];

    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Sentry-Auth"], authHeader);
    XCTAssertNil(error);
}

- (void)testMissingScheme
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testMissingHost
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @"http:///1" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testUnsupportedProtocol
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @"ftp://sentry.io/1" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testDsnUrl
{
    NSError *error = nil;
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username:password@getsentry.net/1"
                                      didFailWithError:&error];

    XCTAssertEqualObjects(
        [[dsn getStoreEndpoint] absoluteString], @"https://getsentry.net/api/1/store/");
    XCTAssertNil(error);

    SentryDsn *dsn2 =
        [[SentryDsn alloc] initWithString:@"https://username:password@sentry.io/foo/bar/baz/1"
                         didFailWithError:&error];

    XCTAssertEqualObjects(
        [[dsn2 getStoreEndpoint] absoluteString], @"https://sentry.io/foo/bar/baz/api/1/store/");
    XCTAssertNil(error);
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

- (void)testGetStoreDsnCachesResult
{
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"https://username:password@getsentry.net/1"
                                      didFailWithError:nil];

    XCTAssertNotNil([dsn getStoreEndpoint]);
    // Assert same reference
    XCTAssertTrue([dsn getStoreEndpoint] == [dsn getStoreEndpoint]);
}

- (void)testInitWithInvalidString
{
    SentryDsn *dsn = [[SentryDsn alloc] initWithString:@"This is invalid DSN"
                                      didFailWithError:nil];
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
